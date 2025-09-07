#!/usr/bin/env bash
set -euo pipefail
eval $(minikube docker-env)
echo "Building image..."
docker build -t demo-metrics:0.1 ./app
MINIKUBE_IP=$(minikube ip)
APP_HOST="app.${MINIKUBE_IP}.nip.io"
echo "Using host: ${APP_HOST}"
echo "Installing/upgrading Helm release..."
helm upgrade --install demo charts/demo-metrics \
  --set image.repository=demo-metrics \
  --set image.tag=0.1 \
  --set ingress.enabled=true \
  --set ingress.host=${APP_HOST} \
  --set config.APP_MESSAGE="Hello from Helm on Minikube!"
echo "Waiting for rollout..."
kubectl rollout status deploy/demo-demo-metrics --timeout=120s || true
echo "Resources:"
kubectl get pods,svc,ingress
echo "Testing endpoints:"
echo "curl http://${APP_HOST}/"
curl -i "http://${APP_HOST}/" || true
echo "curl http://${APP_HOST}/metrics | head"
curl -s "http://${APP_HOST}/metrics" | head -n 30 || true
echo "Done."
