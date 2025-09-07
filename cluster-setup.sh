#!/bin/bash
set -e
echo "=== Cleaning up old Minikube cluster (if any) ==="
minikube delete || true
echo "=== Starting Minikube with Kubernetes v1.30 ==="
minikube start --driver=docker --kubernetes-version=v1.30.0
echo "=== Verifying cluster status ==="
minikube kubectl -- get nodes -o wide | tee cluster-nodes.log
minikube kubectl -- get pods -A | tee cluster-pods.log
echo "=== Checking kube-apiserver logs for garbage collector ==="
APISERVER_POD=$(minikube kubectl -- get pods -n kube-system -l component=kube-apiserver -o jsonpath='{.items[0].metadata.name}')
minikube kubectl -- logs -n kube-system $APISERVER_POD | grep -i garbage | tee cluster-gc.log
echo "=== Summary ==="
echo "Cluster nodes saved to cluster-nodes.log"
echo "Pods list saved to cluster-pods.log"
echo "Garbage collector logs saved to cluster-gc.log"
