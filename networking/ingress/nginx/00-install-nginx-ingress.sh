#!/bin/bash
set -e

echo "🚀 Installing NGINX Ingress Controller..."

# Add Helm repository
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

# Detect cloud provider
CLOUD_PROVIDER="unknown"
if kubectl get nodes -o json | grep -q "eks.amazonaws.com"; then
    CLOUD_PROVIDER="eks"
elif kubectl get nodes -o json | grep -q "gke"; then
    CLOUD_PROVIDER="gke"
elif kubectl get nodes -o json | grep -q "azure"; then
    CLOUD_PROVIDER="aks"
fi

echo "📍 Detected cloud provider: ${CLOUD_PROVIDER}"

# Install based on cloud provider
case ${CLOUD_PROVIDER} in
    eks)
        echo "Installing for AWS EKS..."
        helm install ingress-nginx ingress-nginx/ingress-nginx \
          --namespace ingress-nginx \
          --create-namespace \
          --set controller.service.type=LoadBalancer \
          --set controller.service.annotations."service\.beta\.kubernetes\.io/aws-load-balancer-type"="nlb" \
          --set controller.service.annotations."service\.beta\.kubernetes\.io/aws-load-balancer-scheme"="internet-facing" \
          --set controller.service.annotations."service\.beta\.kubernetes\.io/aws-load-balancer-cross-zone-load-balancing-enabled"="true"
        ;;
    gke)
        echo "Installing for Google GKE..."
        helm install ingress-nginx ingress-nginx/ingress-nginx \
          --namespace ingress-nginx \
          --create-namespace \
          --set controller.service.type=LoadBalancer
        ;;
    aks)
        echo "Installing for Azure AKS..."
        helm install ingress-nginx ingress-nginx/ingress-nginx \
          --namespace ingress-nginx \
          --create-namespace \
          --set controller.service.type=LoadBalancer
        ;;
    *)
        echo "Installing for generic Kubernetes..."
        helm install ingress-nginx ingress-nginx/ingress-nginx \
          --namespace ingress-nginx \
          --create-namespace \
          --set controller.service.type=LoadBalancer
        ;;
esac

echo ""
echo "⏳ Waiting for NGINX Ingress Controller to be ready..."
kubectl wait --for=condition=ready pod \
  -l app.kubernetes.io/name=ingress-nginx \
  -n ingress-nginx \
  --timeout=300s

echo ""
echo "✅ NGINX Ingress Controller installed successfully!"
echo ""
echo "📍 LoadBalancer details:"
kubectl get svc ingress-nginx-controller -n ingress-nginx

echo ""
echo "🎯 Next steps:"
echo "1. Configure DNS to point to the LoadBalancer IP/hostname"
echo "2. Apply REC UI Ingress: kubectl apply -f 01-ingress-rec-ui.yaml"
echo "3. Configure TCP services: kubectl apply -f 02-tcp-configmap.yaml"
echo "4. Patch service for database ports: kubectl apply -f 03-patch-nginx-service.yaml"

