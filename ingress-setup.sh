#!/usr/bin/env bash
set -euo pipefail
minikube addons enable ingress
kubectl -n ingress-nginx rollout status deploy/ingress-nginx-controller --timeout=120s
echo "NGINX Ingress ready."
