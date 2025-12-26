#!/bin/bash
set -e

echo "🚀 Installing Istio..."

# Download Istio
echo "📥 Downloading Istio..."
curl -L https://istio.io/downloadIstio | ISTIO_VERSION=1.20.0 sh -

cd istio-1.20.0
export PATH=$PWD/bin:$PATH

# Install Istio with default profile
echo "⚙️ Installing Istio with default profile..."
istioctl install --set profile=default -y

# Enable sidecar injection for redis-enterprise namespace
echo "🔧 Enabling sidecar injection for redis-enterprise namespace..."
kubectl label namespace redis-enterprise istio-injection=enabled --overwrite

echo ""
echo "⏳ Waiting for Istio to be ready..."
kubectl wait --for=condition=ready pod \
  -l app=istiod \
  -n istio-system \
  --timeout=300s

echo ""
echo "✅ Istio installed successfully!"
echo ""
echo "📍 Ingress Gateway details:"
kubectl get svc istio-ingressgateway -n istio-system

echo ""
echo "🎯 Next steps:"
echo "1. Configure DNS to point to the Ingress Gateway IP/hostname"
echo "2. Apply Gateway: kubectl apply -f 01-gateway-rec-ui.yaml"
echo "3. Apply VirtualService: kubectl apply -f 02-virtualservice-rec-ui.yaml"
echo "4. Apply Database Gateway: kubectl apply -f 03-gateway-database.yaml"
echo "5. Apply Database VirtualService: kubectl apply -f 04-virtualservice-database.yaml"

