# EscolarOnline — Migracion a EKS + RDS Multi-AZ

## Descripcion

Migracion de la aplicacion EscolarOnline desde EC2+Docker manual (EA1) hacia Amazon EKS (orquestacion de contenedores) y Amazon RDS MySQL Multi-AZ (servicio PaaS gestionado). Misma funcionalidad CRUD, plataforma gestionada.

## Arquitectura TO-BE (EA2)

| Capa | Componente | Servicio AWS | Configuracion |
|------|-----------|--------------|---------------|
| Publica | ALB Ingress | ALB | Creado por Ingress Controller |
| Privada APP | EKS Cluster + Node Group | EKS | 2-4 nodos t4g.small Multi-AZ |
| Privada APP | 5 Deployments x 2 replicas | Pods | 10 pods total |
| Privada DATA | RDS MySQL Multi-AZ | RDS | db.t4g.micro, failover automatico |
| Registro | 5 repositorios | ECR | Imagenes ARM64 |
| Observabilidad | Container Insights | CloudWatch | Metricas por pod |

## Estructura de Archivos

```
02-ea2/desarrolloapp/
├── README.md                     (este archivo)
├── init.sql                      (script BD para RDS MySQL)
├── k8s/
│   ├── namespace.yaml
│   ├── configmap.yaml
│   ├── secret.yaml
│   ├── frontend-deployment.yaml
│   ├── frontend-service.yaml
│   ├── get-products-deployment.yaml
│   ├── get-products-service.yaml
│   ├── create-product-deployment.yaml
│   ├── create-product-service.yaml
│   ├── update-product-deployment.yaml
│   ├── update-product-service.yaml
│   ├── delete-product-deployment.yaml
│   ├── delete-product-service.yaml
│   ├── ingress.yaml
│   ├── hpa-get-products.yaml
│   ├── hpa-create-product.yaml
│   ├── hpa-update-product.yaml
│   └── hpa-delete-product.yaml
└── scripts/
    └── ecr-push.sh               (build ARM64 + push a ECR)
```

## Microservicios (mismos de EA1, sin cambios de codigo)

| Pod | Imagen ECR | Puerto | Endpoint |
|-----|-----------|--------|----------|
| frontend | escolaronline-frontend:latest | 80 | / |
| get-products | escolaronline-get-products:latest | 3001 | /api/products (GET) |
| create-product | escolaronline-create-product:latest | 3002 | /api/products (POST) |
| update-product | escolaronline-update-product:latest | 3003 | /api/products/:id (PUT) |
| delete-product | escolaronline-delete-product:latest | 3004 | /api/products/:id (DELETE) |

> Nota: El codigo fuente de los microservicios es el mismo de EA1 (`01-ea1/desarrolloapp/`). Solo cambia DONDE se ejecutan (EKS en vez de EC2+Docker manual).

## Variables de Entorno

| Variable | Valor en RDS |
|----------|-------------|
| DB_HOST | (endpoint RDS, ej: escolaronline-db.xxxxx.us-east-1.rds.amazonaws.com) |
| DB_USER | alumno |
| DB_PASS | alumno123 |
| DB_NAME | escolar_online |
| DB_PORT | 3306 |

## Guia de Implementacion

Consultar: **Act-2.3-Anexo-Paso-a-Paso-Implementacion-EKS.md**

---

2026 - Disenador: Ignacio A. Pastenet M.
