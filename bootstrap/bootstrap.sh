#!/bin/bash
set -e

echo "=== Bootstrap de SRE Observability Platform ==="
echo ""

# 1. Borrar cluster si existe
echo "=== 1. Limpiando cluster anterior ==="
if k3d cluster list | grep -q "sre-lab"; then
    echo "El cluster ya existe. Borrándolo..."
    k3d cluster delete sre-lab
else
    echo "No hay cluster previo."
fi

# 2. Crear cluster
echo ""
echo "=== 2. Creando cluster ==="
k3d cluster create --config k3d-config.yaml

# 3. Aplicar namespaces
echo ""
echo "=== 3. Aplicando namespaces ==="
kubectl apply -f bootstrap/namespaces.yaml

# 4. Instalar ArgoCD
echo ""
echo "=== 4. Instalando ArgoCD ==="
#kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl apply --server-side -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
# 5. Instalar Nginx Ingress
echo ""
echo "=== 5. Instalando Nginx Ingress ==="
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/cloud/deploy.yaml

# 6. Aplicar Applications de ArgoCD
echo ""
echo "=== 6. Aplicando Applications de ArgoCD ==="
kubectl apply -f bootstrap/argocd-apps.yaml

echo ""
echo "=== Bootstrap completado ==="

kubectl get nodes
kubectl get namespaces
kubectl get pods -n argocd
kubectl get pods -n ingress-nginx
