#!/bin/bash
set -e

echo "🚀 Installing HAProxy Ingress Controller..."

# Add Helm repository
helm repo add haproxy-ingress https://haproxy-ingress.github.io/charts
helm repo update

# Install HAProxy Ingress
helm install haproxy-ingress haproxy-ingress/haproxy-ingress \
  --namespace ingress-haproxy \
  --create-namespace \
  --set controller.service.type=LoadBalancer

echo ""
echo "⏳ Waiting for HAProxy Ingress Controller to be ready..."
kubectl wait --for=condition=ready pod \
  -l app.kubernetes.io/name=haproxy-ingress \
  -n ingress-haproxy \
  --timeout=300s

echo ""
echo "✅ HAProxy Ingress Controller installed successfully!"
echo ""
echo "📍 LoadBalancer details:"
kubectl get svc haproxy-ingress -n ingress-haproxy

echo ""
echo "🎯 Next steps:"
echo "1. Configure DNS to point to the LoadBalancer IP/hostname"
echo "2. Apply REC UI Ingress: kubectl apply -f 01-ingress-rec-ui.yaml"
echo "3. Apply Database Ingress: kubectl apply -f 02-ingress-database.yaml"

