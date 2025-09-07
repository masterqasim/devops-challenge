# demo-metrics-app

**What this package contains**

- `app/` – Node.js demo application that exposes `/` and `/metrics` (Prometheus exposition format).
- `charts/demo-metrics/` – Helm chart (ConfigMap, Deployment, Service, Ingress, values, helpers).
- `cluster-setup.sh` – convenience script to start Minikube and save logs (nodes, pods, apiserver GC log).
- `ingress-setup.sh` – enables minikube ingress addon and waits for readiness.
- `deploy-app.sh` – builds the Docker image inside Minikube's Docker, installs (or upgrades) the Helm release, and performs quick checks & curl.

---

## Prerequisites (on your EC2 - Amazon Linux 2023)

- A running EC2 instance (t3.medium or larger recommended) with a public IP and security group allowing SSH and ports 80/443 if you want public ingress testing.
- Docker installed and running (`sudo systemctl enable --now docker`) and your user in `docker` group (`sudo usermod -aG docker $USER` then re-login).
- `minikube`, `kubectl`, and `helm` installed on the EC2. If you used the earlier `ec2-setup.sh` I provided, prerequisites should already be installed.

Quick install commands:

```bash
# update
sudo dnf update -y

# docker (Amazon Linux 2023)
sudo dnf install -y docker
sudo systemctl enable --now docker
newgrp docker

# kubectl (optional - minikube kubectl uses matching version)
curl -LO "https://dl.k8s.io/release/$(curl -sL https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl && sudo mv kubectl /usr/local/bin/

# minikube
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube

# helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

---


### 1) Start (or reset) Minikube cluster
This repository includes a helper `cluster-setup.sh`. It will delete an existing cluster, start Minikube (Kubernetes v1.30), and store some logs you can use in your PDF.

Run:

```bash
chmod +x cluster-setup.sh
./cluster-setup.sh
```

### 2) Enable NGINX Ingress
```bash
chmod +x ingress-setup.sh
./ingress-setup.sh
```

This runs:
```bash
minikube addons enable ingress
kubectl -n ingress-nginx rollout status deploy/ingress-nginx-controller --timeout=120s
```

Make sure ingress pods are `Running`:
```bash
kubectl get pods -n ingress-nginx
```

### 3) Build the app image inside Minikube's Docker and deploy via Helm
The `deploy-app.sh` script automates this. It will build the Docker image into Minikube's Docker environment, create a host using `nip.io` (so the ingress host resolves to Minikube IP), and install/upgrade the Helm chart.

Run:

```bash
chmod +x deploy-app.sh
./deploy-app.sh
```

What `deploy-app.sh` does (summary):
- `eval $(minikube docker-env)` to target Minikube's Docker daemon
- `docker build -t demo-metrics:0.1 ./app`
- compute `MINIKUBE_IP=$(minikube ip)` and `APP_HOST="app.${MINIKUBE_IP}.nip.io"`
- `helm upgrade --install demo charts/demo-metrics --set image.repository=demo-metrics --set image.tag=0.1 --set ingress.host=${APP_HOST}`
- waits for rollout and prints `kubectl get pods,svc,ingress` and curls `http://${APP_HOST}/` and `http://${APP_HOST}/metrics`

### 4) Verify manually 
```bash
# build image into minikube docker
eval $(minikube docker-env)
docker build -t demo-metrics:0.1 ./app

# compute host and install helm
MINIKUBE_IP=$(minikube ip)
APP_HOST="app.${MINIKUBE_IP}.nip.io"

helm upgrade --install demo charts/demo-metrics   --set image.repository=demo-metrics   --set image.tag=0.1   --set ingress.enabled=true   --set ingress.host=${APP_HOST}   --set config.APP_MESSAGE="Hello from Helm on Minikube!"

# check objects
kubectl get pods,svc,ingress

# test endpoints
curl -i "http://${APP_HOST}/"
curl -s "http://${APP_HOST}/metrics" | head -n 30
```

### 5) Cleanup
```bash
# delete helm release and minikube
helm uninstall demo
minikube delete 
```
---

## Troubleshooting & Notes

- **Kubectl version mismatch warning**: If you see `/usr/local/bin/kubectl is version X which may be incompatible with cluster v1.30`, use `minikube kubectl -- get pods -A` to run the kubectl version matching the cluster.
- **--garbage-collector-threads flag**: When we tried to pass `--extra-config=apiserver.garbage-collector-threads=10` Minikube failed because kube-apiserver returned `unknown flag: --garbage-collector-threads`. This is expected for modern Kubernetes (v1.30) where that flag is removed. Document this attempt and include the Minikube logs in your PDF to demonstrate investigation.
- **Ingress host**: We use `nip.io` to easily resolve `app.<MINIKUBE_IP>.nip.io` to the minikube IP. If your company blocks DNS, you can use `/etc/hosts` mapping or access via `minikube service` (though `minikube service` uses NodePort and is less production-like).
- **Port access**: If you want to access the app from your laptop directly to the EC2 public IP, ensure EC2 security group allows HTTP (80) and that the Minikube VM forwards traffic (Minikube with docker driver maps host ports via the ingress controller).

---
## Files in this package
```
/app                     # Node.js app (index.js, package.json, Dockerfile)
/charts/demo-metrics     # Helm chart and templates
cluster-setup.sh
ingress-setup.sh
deploy-app.sh
README.md                # <-- you are reading this
```
