#!/bin/bash
set -e
cd "$(dirname "$0")/.."
source scripts/00-env.sh
[ -z "$VPC_ID" ] && { echo "ERROR: no existe la infraestructura."; exit 1; }
aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "$AWS_DEFAULT_REGION" >/dev/null
kubectl config use-context "arn:aws:eks:${AWS_DEFAULT_REGION}:${ACCOUNT_ID}:cluster/${CLUSTER_NAME}"
kubectl get nodes -o wide || true
READY_COUNT=$(kubectl get nodes --no-headers 2>/dev/null | grep -c " Ready " || true)
if [ "$READY_COUNT" -lt 2 ]; then
  echo "--- Reciclando instancias del node group ---"
  for ID in $(aws ec2 describe-instances --filters "Name=tag:eks:nodegroup-name,Values=${NODEGROUP_NAME}" "Name=instance-state-name,Values=running" --query "Reservations[].Instances[].InstanceId" --output text); do
    aws autoscaling terminate-instance-in-auto-scaling-group --instance-id "$ID" --no-should-decrement-desired-capacity >/dev/null
  done
  echo "esperando ~3 min..."
  for i in $(seq 1 18); do
    sleep 10
    READY_COUNT=$(kubectl get nodes --no-headers 2>/dev/null | grep -c " Ready " || true)
    [ "$READY_COUNT" -ge 2 ] && break
  done
fi
echo "--- Nodos ---"; kubectl get nodes -o wide
echo "--- Pods ---"; kubectl get pods -n "$PROJECT_NAME" -o wide 2>/dev/null || echo "(namespace no existe)"
