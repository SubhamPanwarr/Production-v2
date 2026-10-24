#!/usr/bin/env bash
set -euo pipefail

echo "=== Nodes ==="
kubectl get nodes -o wide

echo
echo "=== kube-system ==="
kubectl get pods -n kube-system

echo
echo "=== production ==="
kubectl get all -n production

echo
echo "=== HPA / PDB / Ingress / PVC ==="
kubectl get hpa,pdb,ingress,pvc -n production
