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
│       └── aks/                           # AVM aks-production wrapper
└── kubernetes/
    ├── namespace.yaml                     # Namespace + ServiceAccount (workload identity)
    ├── configmap.yaml                     # Non-sensitive config
    ├── secret-provider-class.yaml         # Key Vault CSI driver config
    ├── backend-api/
    │   ├── deployment.yaml                # 2 replicas, probes, security context
    │   ├── service.yaml                   # ClusterIP
    │   └── ingress.yaml                   # NGINX ingress
    └── worker/
        └── deployment.yaml                # Background processor (writes to blob storage)
```

## Key Architecture Decisions

| Component | Choice | Rationale |
|-----------|--------|-----------|
| Ingress | NGINX Ingress Controller | Portable, well-documented, no Azure lock-in |
| Networking | Azure CNI | Pods get VNet IPs, required for network policies |
| Secrets | Key Vault + CSI Driver | Secrets never in cluster, centralized management |
| Identity | Managed Identity + Workload Identity | No credential management |
| IaC | Azure Verified Modules (AVM) | Microsoft-maintained, well-tested, thin wrappers |

## Terraform Modules (AVM-based)

All modules are thin wrappers around Azure Verified Modules:

- **networking**: `Azure/avm-res-network-virtualnetwork/azurerm ~> 0.17` (latest: 0.17.0)
- **monitoring**: `Azure/avm-res-operationalinsights-workspace/azurerm ~> 0.4` (latest: 0.4.2)
- **keyvault**: `Azure/avm-res-keyvault-vault/azurerm ~> 0.10` (latest: 0.10.2)
- **storage**: `Azure/avm-res-storage-storageaccount/azurerm ~> 0.6` (latest: 0.6.7)
- **aks**: `Azure/avm-ptn-aks-production/azurerm ~> 0.5` (latest: 0.5.0)

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
- VM size: `Standard_B2s` (burstable, ~$30/month)
- Log retention: 7 days
- Region: `westeurope`

## CI/CD Pipeline

GitHub Actions workflow (`.github/workflows/ci-cd.yaml`):
1. **build**: Build and test Docker images
2. **push**: Push to Azure Container Registry
3. **deploy-dev**: Deploy to dev on `develop` branch
4. **deploy-prod**: Deploy to prod on `main` branch (requires approval)

Required GitHub secrets/variables:
- `AZURE_CREDENTIALS` - Service principal JSON
- `ACR_LOGIN_SERVER`, `ACR_USERNAME`, `ACR_PASSWORD`
- `AKS_CLUSTER_NAME`, `AKS_RESOURCE_GROUP`
- `WORKLOAD_IDENTITY_CLIENT_ID`, `KEY_VAULT_NAME`, `AZURE_TENANT_ID`

## Reference Documents

- `challenge.md` - Original challenge requirements
- `README.md` - Full architecture documentation with Mermaid diagram
