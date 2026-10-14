#!/bin/bash
set -e
cd "$(dirname "$0")/.."
source scripts/00-env.sh
[ -z "$VPC_ID" ] && { echo "ERROR: corre primero ./scripts/01-infra.sh"; exit 1; }
[ -z "$RDS_ENDPOINT" ] && { echo "ERROR: no existe RDS, corre ./scripts/01-infra.sh"; exit 1; }
aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "$AWS_DEFAULT_REGION" >/dev/null
kubectl config use-context "arn:aws:eks:${AWS_DEFAULT_REGION}:${ACCOUNT_ID}:cluster/${CLUSTER_NAME}" >/dev/null

echo "--- Build y push de imagenes (si Docker esta corriendo) ---"
if docker info >/dev/null 2>&1; then
  aws ecr get-login-password --region "$AWS_DEFAULT_REGION" | docker login --username AWS --password-stdin "$ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com" >/dev/null
  REPOS=("${PROJECT_NAME}-frontend" "${PROJECT_NAME}-get-products" "${PROJECT_NAME}-create-product" "${PROJECT_NAME}-update-product" "${PROJECT_NAME}-delete-product")
  DIRS=("microservicioEKSFrontend" "microserviciosEKSBackend/get-products" "microserviciosEKSBackend/create-product" "microserviciosEKSBackend/update-product" "microserviciosEKSBackend/delete-product")
  for REPO in "${REPOS[@]}"; do aws ecr create-repository --repository-name "$REPO" --region "$AWS_DEFAULT_REGION" >/dev/null 2>&1 || true; done
  for i in "${!REPOS[@]}"; do
    docker build --platform linux/arm64 -t "${REPOS[$i]}" "./${DIRS[$i]}"
    docker tag "${REPOS[$i]}" "$ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/${REPOS[$i]}:latest"
    docker push "$ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/${REPOS[$i]}:latest"
  done
else
  echo "Docker no esta corriendo, se usan las imagenes ya existentes en ECR."
fi

echo "--- Poblando BD si esta vacia ---"
kubectl delete pod db-seed --ignore-not-found -n default >/dev/null 2>&1 || true
kubectl run db-seed --image=mysql:8.0 --restart=Never -n default -- sleep 600 >/dev/null
kubectl wait --for=condition=Ready pod/db-seed -n default --timeout=90s >/dev/null
COUNT=$(kubectl exec -n default db-seed -- mysql -h "$RDS_ENDPOINT" -u "$DB_USER" -p"$DB_PASS" -N -e "SELECT COUNT(*) FROM ${DB_NAME}.productos;" 2>/dev/null || echo "0")
if [ "$COUNT" = "0" ]; then
  kubectl cp init.sql default/db-seed:/tmp/init.sql
  kubectl exec -i -n default db-seed -- mysql -h "$RDS_ENDPOINT" -u "$DB_USER" -p"$DB_PASS" < init.sql
fi
kubectl delete pod db-seed -n default >/dev/null 2>&1 || true

echo "--- Aplicando manifiestos ---"
TMPDIR=$(mktemp -d)
cp -r k8s/* "$TMPDIR/"
sed -i.bak "s/<ACCOUNT_ID>/$ACCOUNT_ID/g" "$TMPDIR"/*-deployment.yaml 2>/dev/null || true
sed -i.bak "s/<RDS_ENDPOINT>/$RDS_ENDPOINT/g" "$TMPDIR"/configmap.yaml 2>/dev/null || true
kubectl apply -f "$TMPDIR/namespace.yaml"
kubectl apply -f "$TMPDIR/configmap.yaml" -f "$TMPDIR/secret.yaml"
kubectl apply -f "$TMPDIR/frontend-deployment.yaml" -f "$TMPDIR/frontend-service.yaml"
kubectl apply -f "$TMPDIR/get-products-deployment.yaml" -f "$TMPDIR/get-products-service.yaml"
kubectl apply -f "$TMPDIR/create-product-deployment.yaml" -f "$TMPDIR/create-product-service.yaml"
kubectl apply -f "$TMPDIR/update-product-deployment.yaml" -f "$TMPDIR/update-product-service.yaml"
kubectl apply -f "$TMPDIR/delete-product-deployment.yaml" -f "$TMPDIR/delete-product-service.yaml"
kubectl rollout restart deployment -n "$PROJECT_NAME" >/dev/null
kubectl rollout status deployment -n "$PROJECT_NAME" --timeout=180s || true

if ! kubectl get ns cert-manager >/dev/null 2>&1; then
  kubectl apply --validate=false -f https://github.com/jetstack/cert-manager/releases/download/v1.12.0/cert-manager.yaml
  kubectl wait --for=condition=Available deployment --all -n cert-manager --timeout=180s
fi
if ! helm status aws-load-balancer-controller -n kube-system >/dev/null 2>&1; then
  helm repo add eks https://aws.github.io/eks-charts >/dev/null 2>&1 || true
  helm repo update >/dev/null
  helm install aws-load-balancer-controller eks/aws-load-balancer-controller -n kube-system \
    --set clusterName="$CLUSTER_NAME" --set region="$AWS_DEFAULT_REGION" --set vpcId="$VPC_ID" \
    --set serviceAccount.create=true --set serviceAccount.name=aws-load-balancer-controller
  kubectl rollout status deployment/aws-load-balancer-controller -n kube-system --timeout=120s
fi
if ! kubectl get deployment metrics-server -n kube-system >/dev/null 2>&1; then
  kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
fi

kubectl apply -f "$TMPDIR/ingress.yaml"
kubectl apply -f "$TMPDIR"/hpa-*.yaml
rm -rf "$TMPDIR"

echo "--- Esperando DNS del ALB ---"
for i in $(seq 1 18); do
  ALB_DNS=$(kubectl get ingress -n "$PROJECT_NAME" -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}' 2>/dev/null)
  [ -n "$ALB_DNS" ] && break
  sleep 10
done
echo "=== Deploy completo ==="
kubectl get pods -n "$PROJECT_NAME"
[ -n "$ALB_DNS" ] && echo "URL: http://$ALB_DNS"
