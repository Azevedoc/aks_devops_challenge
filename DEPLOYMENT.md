# Deployment Guide

This guide covers deploying the AKS platform on Azure, with specific guidance for **free tier subscriptions** with $200 credit.

---

## Prerequisites

### Required Tools

| Tool | Version | Installation |
|------|---------|--------------|
| Azure CLI | 2.50+ | `curl -sL https://aka.ms/InstallAzureCLIDeb \| sudo bash` |
| Terraform | 1.5+ | [terraform.io/downloads](https://terraform.io/downloads) |
| kubectl | 1.28+ | `az aks install-cli` |
| kubelogin | 0.1+ | [github.com/Azure/kubelogin](https://github.com/Azure/kubelogin/releases) |

### Azure Authentication

```bash
# Login to Azure
az login

# Verify subscription
az account show

# Set subscription (if you have multiple)
az account set --subscription "YOUR_SUBSCRIPTION_ID"
```

---

## Free Tier Subscription Considerations

### Limitations

Free Azure subscriptions ($200 credit) have restrictions not well-documented:

| Limitation | Impact | Workaround |
|------------|--------|------------|
| **No Availability Zones** | Cannot use zone-redundant configurations | Use single-zone deployment |
| **Regional VM Restrictions** | Some regions don't have basic VM SKUs | Use recommended regions |
| **vCPU Quota** | 4 vCPUs total per region | Use small VM sizes |
| **Key Vault Soft-Delete** | 7-90 day retention blocks name reuse | Purge before recreating |

### Recommended Regions

Based on testing, these regions have better VM availability for free subscriptions:

| Region | VM Availability | Recommended |
|--------|-----------------|-------------|
| **westus2** | Good - B-series, D-series available | Yes |
| **eastus2** | Good - Most SKUs available | Yes |
| **centralus** | Good - Basic SKUs available | Yes |
| eastus | Limited - Many SKUs restricted | No |
| westeurope | Limited - Zone requirements | No |
| northeurope | Limited - Zone requirements | No |

### Recommended VM Sizes

For AKS nodes on free subscriptions:

| VM Size | vCPUs | RAM | Cost/month | Notes |
|---------|-------|-----|------------|-------|
| **Standard_B2s_v2** | 2 | 4 GB | ~$35 | Best for demos |
| Standard_B2als_v2 | 2 | 4 GB | ~$30 | AMD-based alternative |
| Standard_D2s_v3 | 2 | 8 GB | ~$70 | More memory |
| Standard_D2as_v5 | 2 | 8 GB | ~$60 | If available |

**Check availability before deploying:**

```bash
# List available VM sizes in a region
az vm list-skus --location westus2 --resource-type virtualMachines \
  --query "[?contains(name, 'Standard_B2') || contains(name, 'Standard_D2')].name" -o tsv
```

---

## Deployment Steps

### 1. Clone and Configure

```bash
# Clone repository
git clone <repository-url>
cd aks_devops_challenge/terraform

# Copy example configuration
cp environments/dev.tfvars.example environments/dev.tfvars
```

### 2. Edit Configuration

Edit `environments/dev.tfvars`:

```hcl
# REQUIRED: Your Azure subscription ID
subscription_id = "YOUR_SUBSCRIPTION_ID"

# Project naming
project     = "aksplatform"
environment = "dev"

# IMPORTANT: Use a region with good VM availability
location    = "westus2"  # Recommended for free tier

# Networking
vnet_address_space            = "10.0.0.0/16"
aks_subnet_cidr               = "10.0.1.0/24"
private_endpoints_subnet_cidr = "10.0.2.0/24"

# AKS Configuration
kubernetes_version = "1.33"           # Or latest stable
aks_node_size      = "Standard_B2s_v2"  # Recommended for free tier

# Monitoring
log_retention_days = 30  # Minimum allowed
```

### 3. Deploy Infrastructure

```bash
cd terraform

# Initialize Terraform
terraform init

# Preview changes
terraform plan -var-file=environments/dev.tfvars

# Deploy (takes ~10 minutes)
terraform apply -var-file=environments/dev.tfvars
```

### 4. Configure Kubernetes Access

```bash
# Get AKS credentials
az aks get-credentials \
  --resource-group aksplatform-dev-rg \
  --name aksplatform-dev-aks \
  --admin

# Convert kubeconfig for Azure CLI auth
kubelogin convert-kubeconfig -l azurecli

# Verify connection
kubectl get nodes
```

### 5. Grant RBAC Permissions (if using Azure RBAC)

```bash
# Get your user ID
USER_ID=$(az ad signed-in-user show --query id -o tsv)

# Get AKS resource ID
AKS_ID=$(az aks show -g aksplatform-dev-rg -n aksplatform-dev-aks --query id -o tsv)

# Grant cluster admin role
az role assignment create \
  --assignee "$USER_ID" \
  --role "Azure Kubernetes Service RBAC Cluster Admin" \
  --scope "$AKS_ID"

# Grant Key Vault access
KV_ID=$(az keyvault show -n aksplatformdevkv --query id -o tsv)
az role assignment create \
  --assignee "$USER_ID" \
  --role "Key Vault Secrets Officer" \
  --scope "$KV_ID"
```

### 6. Deploy NGINX Ingress Controller

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.12.0/deploy/static/provider/cloud/deploy.yaml

# Wait for external IP
kubectl get svc -n ingress-nginx ingress-nginx-controller -w
```

### 7. Create Key Vault Secrets

```bash
# Create application secret
az keyvault secret set \
  --vault-name aksplatformdevkv \
  --name app-secret \
  --value "your-secret-value"

# Create storage connection string
STORAGE_CONN=$(az storage account show-connection-string \
  --name aksplatformdevsa \
  --resource-group aksplatform-dev-rg \
  --query connectionString -o tsv)

az keyvault secret set \
  --vault-name aksplatformdevkv \
  --name storage-connection-string \
  --value "$STORAGE_CONN"
```

### 8. Configure Workload Identity

Workload Identity allows pods to authenticate to Azure services (Key Vault, Storage) without storing credentials.

```bash
# Get OIDC issuer URL from AKS
OIDC_ISSUER=$(az aks show \
  --name aksplatform-dev-aks \
  --resource-group aksplatform-dev-rg \
  --query "oidcIssuerProfile.issuerUrl" -o tsv)

echo "OIDC Issuer: $OIDC_ISSUER"

# Create user-assigned managed identity
az identity create \
  --name "aksplatform-workload-identity" \
  --resource-group "aksplatform-dev-rg" \
  --location "westus2"

# Get identity details
WORKLOAD_IDENTITY_CLIENT_ID=$(az identity show \
  --name "aksplatform-workload-identity" \
  --resource-group "aksplatform-dev-rg" \
  --query "clientId" -o tsv)

WORKLOAD_IDENTITY_PRINCIPAL_ID=$(az identity show \
  --name "aksplatform-workload-identity" \
  --resource-group "aksplatform-dev-rg" \
  --query "principalId" -o tsv)

echo "Client ID: $WORKLOAD_IDENTITY_CLIENT_ID"
echo "Principal ID: $WORKLOAD_IDENTITY_PRINCIPAL_ID"

# Create federated credential linking K8s service account to Azure identity
az identity federated-credential create \
  --name "kubernetes-federated-credential" \
  --identity-name "aksplatform-workload-identity" \
  --resource-group "aksplatform-dev-rg" \
  --issuer "$OIDC_ISSUER" \
  --subject "system:serviceaccount:app:app-workload-identity" \
  --audiences "api://AzureADTokenExchange"

# Grant Key Vault Secrets User role
az role assignment create \
  --assignee "$WORKLOAD_IDENTITY_PRINCIPAL_ID" \
  --role "Key Vault Secrets User" \
  --scope "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/aksplatform-dev-rg/providers/Microsoft.KeyVault/vaults/aksplatformdevkv"

# Grant Storage Blob Data Contributor role
az role assignment create \
  --assignee "$WORKLOAD_IDENTITY_PRINCIPAL_ID" \
  --role "Storage Blob Data Contributor" \
  --scope "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/aksplatform-dev-rg/providers/Microsoft.Storage/storageAccounts/aksplatformdevsa"
```

### 9. Deploy Kubernetes Manifests

```bash
cd ../kubernetes

# Get ingress IP for hostname
INGRESS_IP=$(kubectl get svc -n ingress-nginx ingress-nginx-controller \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Set environment variables for manifest substitution
export ACR_LOGIN_SERVER=$(terraform -chdir=../terraform output -raw acr_login_server)
export IMAGE_TAG="latest"
export INGRESS_HOST="api.${INGRESS_IP}.nip.io"
export WORKLOAD_IDENTITY_CLIENT_ID="$WORKLOAD_IDENTITY_CLIENT_ID"
export KEY_VAULT_NAME="aksplatformdevkv"
export AZURE_TENANT_ID=$(az account show --query tenantId -o tsv)

# Substitute variables in manifests
for file in *.yaml **/*.yaml; do
  if [ -f "$file" ]; then
    envsubst < "$file" > "${file}.tmp" && mv "${file}.tmp" "$file"
  fi
done

# Deploy namespace and config
kubectl apply -f namespace.yaml
kubectl apply -f configmap.yaml
kubectl apply -f secret-provider-class.yaml

# Deploy workloads
kubectl apply -f backend-api/
kubectl apply -f worker/

# Verify deployment
kubectl get all -n app

# Verify secrets are mounted
kubectl exec -n app deployment/backend-api -- ls -la /mnt/secrets-store/
```

---

## CI/CD Setup (GitHub Actions)

To enable automated deployments via GitHub Actions, follow these steps.

### 1. Create Service Principal

```bash
# Create service principal with Contributor role
SP_OUTPUT=$(az ad sp create-for-rbac \
  --name "github-actions-aks-deploy" \
  --role contributor \
  --scopes "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/aksplatform-dev-rg" \
  --sdk-auth)

echo "$SP_OUTPUT"

# Extract values for GitHub secrets
SP_CLIENT_ID=$(echo "$SP_OUTPUT" | jq -r '.clientId')
SP_CLIENT_SECRET=$(echo "$SP_OUTPUT" | jq -r '.clientSecret')
SP_TENANT_ID=$(echo "$SP_OUTPUT" | jq -r '.tenantId')
```

### 2. Grant AKS RBAC Permissions

The service principal needs explicit AKS RBAC permissions (separate from Azure resource RBAC):

```bash
# Get service principal object ID
SP_OBJECT_ID=$(az ad sp show --id "$SP_CLIENT_ID" --query id -o tsv)

# Grant AKS RBAC Cluster Admin role
az role assignment create \
  --assignee "$SP_OBJECT_ID" \
  --role "Azure Kubernetes Service RBAC Cluster Admin" \
  --scope "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/aksplatform-dev-rg/providers/Microsoft.ContainerService/managedClusters/aksplatform-dev-aks"
```

### 3. Configure GitHub Secrets

Using GitHub CLI or the web interface, set these secrets:

```bash
# Install GitHub CLI if needed: https://cli.github.com/

# Login to GitHub
gh auth login

# Set secrets
gh secret set AZURE_CREDENTIALS --body "$SP_OUTPUT"
gh secret set AZURE_CLIENT_ID --body "$SP_CLIENT_ID"
gh secret set AZURE_CLIENT_SECRET --body "$SP_CLIENT_SECRET"
gh secret set AZURE_TENANT_ID --body "$SP_TENANT_ID"

# Get ACR credentials
ACR_USERNAME=$(terraform -chdir=terraform output -raw acr_admin_username)
ACR_PASSWORD=$(terraform -chdir=terraform output -raw acr_admin_password)

gh secret set ACR_USERNAME --body "$ACR_USERNAME"
gh secret set ACR_PASSWORD --body "$ACR_PASSWORD"
```

### 4. Configure GitHub Variables

```bash
# Get values from Terraform outputs
ACR_LOGIN_SERVER=$(terraform -chdir=terraform output -raw acr_login_server)
AKS_CLUSTER_NAME=$(terraform -chdir=terraform output -raw aks_cluster_name)
KEY_VAULT_NAME=$(terraform -chdir=terraform output -raw key_vault_name)
INGRESS_IP=$(kubectl get svc -n ingress-nginx ingress-nginx-controller \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Set variables
gh variable set ACR_LOGIN_SERVER --body "$ACR_LOGIN_SERVER"
gh variable set AKS_CLUSTER_NAME --body "$AKS_CLUSTER_NAME"
gh variable set AKS_RESOURCE_GROUP --body "aksplatform-dev-rg"
gh variable set INGRESS_HOST --body "api.${INGRESS_IP}.nip.io"
gh variable set KEY_VAULT_NAME --body "$KEY_VAULT_NAME"
gh variable set AZURE_TENANT_ID --body "$SP_TENANT_ID"
gh variable set WORKLOAD_IDENTITY_CLIENT_ID --body "$WORKLOAD_IDENTITY_CLIENT_ID"
```

### 5. Trigger Deployment

Push a commit to the `main` branch to trigger the CI/CD pipeline:

```bash
git push origin main

# Watch the workflow
gh run watch
```

---

## Summary of Manual Steps

| Step | Command/Action | Purpose |
|------|----------------|---------|
| NGINX Ingress | `kubectl apply -f ...` | Ingress controller for external access |
| Key Vault Secrets | `az keyvault secret set` | Application secrets |
| Workload Identity | `az identity create` | Pod-to-Azure authentication |
| Federated Credential | `az identity federated-credential create` | Link K8s SA to Azure identity |
| RBAC Roles | `az role assignment create` | Grant identity access to KV/Storage |
| Service Principal | `az ad sp create-for-rbac` | CI/CD authentication |
| AKS RBAC | `az role assignment create` | Grant SP kubectl access |
| GitHub Secrets | `gh secret set` | CI/CD secrets |
| GitHub Variables | `gh variable set` | CI/CD configuration |

---

## Verification

### Check Infrastructure

```bash
# Terraform outputs
cd terraform
terraform output

# Azure resources
az resource list -g aksplatform-dev-rg -o table
```

### Check Kubernetes

```bash
# Nodes
kubectl get nodes

# All resources in app namespace
kubectl get all -n app

# Ingress status
kubectl get ingress -n app

# Pod logs
kubectl logs -n app -l app.kubernetes.io/name=backend-api
```

### Test Endpoints

```bash
# Get ingress IP
INGRESS_IP=$(kubectl get svc -n ingress-nginx ingress-nginx-controller \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Test API (using nip.io for DNS)
curl http://api.${INGRESS_IP}.nip.io/
```

---

## Cleanup

### Destroy All Resources

```bash
# Delete workload identity (created via CLI, not Terraform)
az identity delete \
  --name "aksplatform-workload-identity" \
  --resource-group "aksplatform-dev-rg"

# Delete service principal (if created for CI/CD)
SP_ID=$(az ad sp list --display-name "github-actions-aks-deploy" --query "[0].id" -o tsv)
az ad sp delete --id "$SP_ID"

cd terraform

# Destroy infrastructure
terraform destroy -var-file=environments/dev.tfvars

# Purge soft-deleted Key Vault (if recreating later)
az keyvault purge --name aksplatformdevkv --location westus2
```

### Check for Orphaned Resources

```bash
# List all resources with project name
az resource list --query "[?contains(name, 'aksplatform')]" -o table

# List resource groups
az group list --query "[?contains(name, 'aksplatform') || contains(name, 'MC_')]" -o table

# Clean up Network Watchers (auto-created by Azure)
az group delete --name NetworkWatcherRG --yes --no-wait
```

---

## Troubleshooting

### VM Size Not Available

**Error:** `The agent pool VM size 'xxx' is not available in location 'yyy'`

**Solution:**
1. Check available SKUs: `az vm list-skus --location <region> -o table | grep Standard_B2`
2. Try a different region (westus2, eastus2, centralus)
3. Use a different VM size from the recommended list

### Key Vault Already Exists

**Error:** `VaultAlreadyExists: The vault name 'xxx' is already in use`

**Solution:**
```bash
# List soft-deleted vaults
az keyvault list-deleted -o table

# Purge the vault
az keyvault purge --name <vault-name> --location <location>
```

### RBAC Permission Denied

**Error:** `User does not have access to the resource in Azure`

**Solution:**
1. Wait 2-5 minutes for RBAC propagation
2. Use admin credentials: `az aks get-credentials --admin`
3. Verify role assignment: `az role assignment list --scope <resource-id>`

### Terraform State Drift

**Error:** Resource exists in Azure but not in Terraform state

**Solution:**
```bash
# Import existing resource
terraform import -var-file=environments/dev.tfvars '<resource_address>' '<azure_resource_id>'

# Or remove from state if resource was deleted
terraform state rm '<resource_address>'
```

---

## Cost Estimation (Free Tier)

| Resource | Monthly Cost | Notes |
|----------|--------------|-------|
| AKS Control Plane | Free | Free tier |
| VM (Standard_B2s_v2) | ~$35 | 1 node |
| Storage Account (LRS) | ~$2 | Minimal usage |
| Log Analytics | ~$5 | 30 day retention |
| Key Vault | ~$0.03 | Per 10k operations |
| Public IP | ~$3 | For ingress |
| **Total** | **~$45/month** | Well within $200 credit |

**Tip:** Destroy resources when not in use to conserve credits.

---

## Architecture Reference

```
┌─────────────────────────────────────────────────────────────┐
│                     Azure (westus2)                         │
│                                                             │
│  ┌───────────────────────────────────────────────────────┐  │
│  │                 aksplatform-dev-rg                    │  │
│  │                                                       │  │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐    │  │
│  │  │    VNet     │  │  Key Vault  │  │   Storage   │    │  │
│  │  │ 10.0.0.0/16 │  │             │  │   Account   │    │  │
│  │  └──────┬──────┘  └─────────────┘  └─────────────┘    │  │
│  │         │                                             │  │
│  │  ┌──────┴──────┐                                      │  │
│  │  │ AKS Cluster │                                      │  │
│  │  │  (1 node)   │                                      │  │
│  │  │             │                                      │  │
│  │  │ ┌─────────┐ │                                      │  │
│  │  │ │ NGINX   │ │ ◄── Public IP (48.x.x.x)             │  │
│  │  │ │ Ingress │ │                                      │  │
│  │  │ └────┬────┘ │                                      │  │
│  │  │      │      │                                      │  │
│  │  │ ┌────┴────┐ │                                      │  │
│  │  │ │   app   │ │                                      │  │
│  │  │ │namespace│ │                                      │  │
│  │  │ │         │ │                                      │  │
│  │  │ │ backend │ │                                      │  │
│  │  │ │ worker  │ │                                      │  │
│  │  │ └─────────┘ │                                      │  │
│  │  └─────────────┘                                      │  │
│  │                                                       │  │
│  │  ┌─────────────┐                                      │  │
│  │  │Log Analytics│                                      │  │
│  │  └─────────────┘                                      │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```
