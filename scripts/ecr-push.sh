#!/bin/bash
# ============================================
# EscolarOnline - Build y Push imagenes a ECR
# Actividad 2.3 - Arquitectura Cloud ARY1102
# ============================================
# Ejecutar desde la carpeta 01-ea1/desarrolloapp/ (codigo fuente)
# Las imagenes son las mismas de EA1, solo se re-pushean a ECR

REGION="us-east-1"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

echo "=== Account ID: $ACCOUNT_ID ==="
echo "=== Region: $REGION ==="

# Login en ECR
echo "=== Autenticando en ECR ==="
aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com

# Crear repositorios ECR (si no existen)
echo "=== Creando repositorios ECR ==="
REPOS=("escolaronline-frontend" "escolaronline-get-products" "escolaronline-create-product" "escolaronline-update-product" "escolaronline-delete-product")

for REPO in "${REPOS[@]}"; do
    aws ecr create-repository --repository-name $REPO --region $REGION 2>/dev/null || echo "Repo $REPO ya existe"
done

# Build imagenes (ARM64 para t4g.small Graviton)
echo "=== Construyendo imagenes Docker (ARM64) ==="
docker build --platform linux/arm64 -t escolaronline-frontend ./microservicioEKSFrontend
docker build --platform linux/arm64 -t escolaronline-get-products ./microserviciosEKSBackend/get-products
docker build --platform linux/arm64 -t escolaronline-create-product ./microserviciosEKSBackend/create-product
docker build --platform linux/arm64 -t escolaronline-update-product ./microserviciosEKSBackend/update-product
docker build --platform linux/arm64 -t escolaronline-delete-product ./microserviciosEKSBackend/delete-product

# Tag imagenes
echo "=== Etiquetando imagenes ==="
docker tag escolaronline-frontend $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/escolaronline-frontend:latest
docker tag escolaronline-get-products $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/escolaronline-get-products:latest
docker tag escolaronline-create-product $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/escolaronline-create-product:latest
docker tag escolaronline-update-product $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/escolaronline-update-product:latest
docker tag escolaronline-delete-product $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/escolaronline-delete-product:latest

# Push imagenes a ECR
echo "=== Subiendo imagenes a ECR ==="
docker push $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/escolaronline-frontend:latest
docker push $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/escolaronline-get-products:latest
docker push $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/escolaronline-create-product:latest
docker push $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/escolaronline-update-product:latest
docker push $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/escolaronline-delete-product:latest

echo "=== Push completado ==="
echo "=== Ahora actualiza los manifiestos K8s con: $ACCOUNT_ID ==="
