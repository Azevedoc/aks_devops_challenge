# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Purpose

This repository implements the Azure Cloud/DevOps Engineer Technical Challenge: a cloud-hosted application with one backend API and one worker/background service running on Azure AKS.

## Current Implementation Status

**Complete** - All deliverables implemented:
- Architecture design with Mermaid diagram in README.md
- Terraform IaC using Azure Verified Modules (AVM)
- Plain Kubernetes manifests with workload identity
- GitHub Actions CI/CD pipeline
- Observability via Container Insights / Log Analytics
- Security via Key Vault CSI driver, managed identity, network policies

## Project Structure

```
aks_devops_challenge/
├── README.md                              # Architecture docs, diagram, key decisions
├── DEPLOYMENT.md                          # Step-by-step deployment guide
├── challenge.md                           # Original challenge requirements
├── .github/workflows/ci-cd.yaml           # GitHub Actions pipeline
├── terraform/
│   ├── main.tf                            # Root module - wires all modules together
│   ├── variables.tf                       # Root variables
│   ├── outputs.tf                         # Root outputs
│   ├── providers.tf                       # azurerm ~> 4.0, terraform >= 1.9
│   ├── environments/dev.tfvars            # Dev config (cost-optimized for demo)
│   └── modules/
│       ├── networking/                    # AVM vnet wrapper (10.0.0.0/16)
│       ├── monitoring/                    # AVM log analytics wrapper
│       ├── keyvault/                      # AVM key vault wrapper
│       ├── storage/                       # AVM storage account wrapper
│       ├── acr/                           # Container registry (direct resource)
│       └── aks/                           # AKS cluster (direct resource)
├── kubernetes/
│   ├── namespace.yaml                     # Namespace + ServiceAccount (workload identity)
│   ├── configmap.yaml                     # Non-sensitive config
│   ├── secret-provider-class.yaml         # Key Vault CSI driver config
│   ├── backend-api/
│   │   ├── deployment.yaml                # 2 replicas, probes, security context
│   │   ├── service.yaml                   # ClusterIP
│   │   └── ingress.yaml                   # NGINX ingress
│   └── worker/
│       └── deployment.yaml                # Background processor (writes to blob storage)
└── src/
    ├── backend-api/                       # Flask API (Dockerfile + main.py)
    └── worker/                            # Background worker (Dockerfile + main.py)
```

## Key Architecture Decisions

| Component | Choice | Rationale |
|-----------|--------|-----------|
| Ingress | NGINX Ingress Controller | Portable, well-documented, no Azure lock-in |
| Networking | Azure CNI + Calico | Pods get VNet IPs, required for network policies |
| Secrets | Key Vault + CSI Driver | Secrets never in cluster, centralized management |
| Identity | Managed Identity + Workload Identity | No credential management |
| IaC | Azure Verified Modules (AVM) | Microsoft-maintained, well-tested, thin wrappers |

## Terraform Modules

| Module | Type | Notes |
|--------|------|-------|
| networking | AVM wrapper | `Azure/avm-res-network-virtualnetwork/azurerm ~> 0.17` |
| monitoring | AVM wrapper | `Azure/avm-res-operationalinsights-workspace/azurerm ~> 0.4` |
| keyvault | AVM wrapper | `Azure/avm-res-keyvault-vault/azurerm ~> 0.10` |
| storage | AVM wrapper | `Azure/avm-res-storage-storageaccount/azurerm ~> 0.6` |
| acr | Direct resource | `azurerm_container_registry` (optional private endpoint) |
| aks | Direct resource | `azurerm_kubernetes_cluster` (AVM pattern requires zones) |

> **Note**: AKS and ACR use direct resources instead of AVM because the AVM production pattern enforces availability zones, which are not available on free Azure subscriptions.

## Common Commands

```bash
# Terraform
cd terraform
terraform init
terraform validate
terraform plan -var-file=environments/dev.tfvars
terraform apply -var-file=environments/dev.tfvars

# Kubernetes (after cluster exists)
kubectl apply -f kubernetes/namespace.yaml
kubectl apply -f kubernetes/configmap.yaml
kubectl apply -f kubernetes/secret-provider-class.yaml
kubectl apply -f kubernetes/backend-api/
kubectl apply -f kubernetes/worker/

# Validate manifests locally
kubectl apply --dry-run=client -f kubernetes/ -R
```

## Environment Configuration

The `environments/dev.tfvars` is configured for a cost-optimized demo:
- VM size: `Standard_B2s_v2` (burstable, ~$35/month)
- Log retention: 30 days (Azure minimum)
- Region: `westus2` (best VM availability for free tier)

## CI/CD Pipeline

GitHub Actions workflow (`.github/workflows/ci-cd.yaml`):
1. **build**: Build and test Docker images
2. **push**: Push to Azure Container Registry
3. **deploy-dev**: Deploy to dev on `develop` branch
4. **deploy-prod**: Deploy to prod on `main` branch

Required GitHub secrets:
- `AZURE_CREDENTIALS` - Service principal JSON
- `AZURE_CLIENT_ID`, `AZURE_CLIENT_SECRET`, `AZURE_TENANT_ID` - For kubelogin
- `ACR_USERNAME`, `ACR_PASSWORD` - ACR admin credentials

Required GitHub variables:
- `ACR_LOGIN_SERVER`, `AKS_CLUSTER_NAME`, `AKS_RESOURCE_GROUP`
- `WORKLOAD_IDENTITY_CLIENT_ID`, `KEY_VAULT_NAME`, `AZURE_TENANT_ID`
- `INGRESS_HOST`

## Manual Configuration (Outside Terraform)

The following resources are created via CLI (documented in DEPLOYMENT.md):
- Workload identity (managed identity + federated credential)
- RBAC role assignments for workload identity
- Service principal for CI/CD
- AKS RBAC role assignment for service principal
- GitHub secrets and variables
- NGINX Ingress Controller
- Key Vault secrets

## Reference Documents

- `challenge.md` - Original challenge requirements
- `README.md` - Architecture documentation with decisions
- `DEPLOYMENT.md` - Step-by-step deployment guide
