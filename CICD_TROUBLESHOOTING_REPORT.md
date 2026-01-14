# CI/CD Pipeline Troubleshooting Report

**Date:** 2026-01-14
**Issue:** GitHub Actions CI/CD Pipeline Failures for AKS Deployment
**Status:** Resolved

---

## Summary

Connecting the GitHub repository to Azure and establishing a working CI/CD pipeline required 8 iterations to resolve. The issues ranged from Git authentication, missing infrastructure (ACR), GitHub Actions authentication to Azure RBAC-enabled AKS, missing files due to `.gitignore` patterns, and Kubernetes workload identity configuration. Resolution involved creating the ACR module, configuring service principal authentication with kubelogin, fixing gitignore rules, and simplifying the demo to remove Key Vault CSI dependencies.

---

## Investigation Process

### 1. Git Authentication — Resolving Credential Conflicts

The initial push to GitHub failed with permission denied errors. The local machine had SSH keys configured for a work GitHub account (`lucasgazevedo`), but the repository belonged to a personal account (`Azevedoc`).

**Errors encountered:**
```
remote: Permission to Azevedoc/aks_devops_challenge.git denied to lucasgazevedo.
fatal: unable to access 'https://github.com/Azevedoc/aks_devops_challenge.git/'
```

**Resolution:** Used a GitHub Personal Access Token (PAT) embedded in the push URL:
```bash
git push https://<PAT>@github.com/Azevedoc/aks_devops_challenge.git main:main
```

### 2. Missing ACR — Discovering Infrastructure Gap

After the initial push, I realized the Terraform infrastructure didn't include Azure Container Registry (ACR). The CI/CD workflow expected to push images to ACR, but no registry existed.

**Resolution:** Created a new ACR Terraform module:
```
terraform/modules/acr/
├── main.tf      # azurerm_container_registry + AcrPull role for AKS
├── variables.tf
└── outputs.tf
```

Applied with `terraform apply -target=module.acr` to create:
- Registry: `aksplatformdevacr.azurecr.io`
- AcrPull role assignment for AKS kubelet identity

### 3. GitHub Actions Setup — Configuring Secrets and Variables

The workflow required multiple secrets and variables. I installed the GitHub CLI and configured:

**Secrets:**
| Secret | Purpose |
|--------|---------|
| `AZURE_CREDENTIALS` | Service principal JSON for Azure login |
| `ACR_USERNAME` | ACR admin username |
| `ACR_PASSWORD` | ACR admin password |
| `AZURE_CLIENT_ID` | SP client ID (added later for kubelogin) |
| `AZURE_CLIENT_SECRET` | SP client secret (added later for kubelogin) |
| `AZURE_TENANT_ID` | Tenant ID (added later for kubelogin) |

**Variables:**
| Variable | Value |
|----------|-------|
| `ACR_LOGIN_SERVER` | `aksplatformdevacr.azurecr.io` |
| `AKS_CLUSTER_NAME` | `aksplatform-dev-aks` |
| `AKS_RESOURCE_GROUP` | `aksplatform-dev-rg` |
| `INGRESS_HOST` | `api.48.202.8.8.nip.io` |
| `KEY_VAULT_NAME` | `aksplatformdevkv` |
| `AZURE_TENANT_ID` | `3adf5cfb-aacd-40e5-8228-5e77f8ed1ae6` |
| `WORKLOAD_IDENTITY_CLIENT_ID` | `placeholder` (caused issues later) |

### 4. kubelogin Not Found — Azure RBAC AKS Authentication

**Run 1 Failed:** The first workflow run failed at the deploy step with:
```
error: executable kubelogin not found
kubelogin is not installed which is required to connect to AAD enabled cluster.
```

Azure RBAC-enabled AKS clusters require `kubelogin` for authentication. GitHub-hosted runners don't have it pre-installed.

**First attempt (failed):** Tried using `azure/kubelogin@v1` action:
```yaml
- name: Install kubelogin
  uses: azure/kubelogin@v1
```
Error: `Unable to resolve action 'azure/kubelogin@v1', unable to find version 'v1'`

**Resolution:** Install kubelogin using Azure CLI:
```yaml
- name: Install kubelogin
  run: |
    az aks install-cli
    kubelogin convert-kubeconfig -l azurecli
```

### 5. Azure RBAC Permission Denied — Service Principal Authorization

**Run 3 Failed:** After fixing kubelogin installation, kubectl commands failed with:
```
namespaces "app" is forbidden: User "ff263189-2dc7-4ad0-8531-df9e9bc6b935"
cannot get resource "namespaces" in API group "" in the namespace "app":
User does not have access to the resource in Azure.
```

The service principal had Contributor role on the resource group but not AKS RBAC permissions.

**Resolution:** Grant AKS RBAC Cluster Admin role:
```bash
az role assignment create \
  --assignee "66521637-ba25-480b-a5d4-997db1bff50c" \
  --role "Azure Kubernetes Service RBAC Cluster Admin" \
  --scope "/subscriptions/.../managedClusters/aksplatform-dev-aks"
```

**Insight:** Azure RBAC for AKS is separate from Azure resource RBAC. A service principal needs explicit AKS RBAC roles even if it has Contributor access to the resource group.

### 6. kubelogin Auth Mode — Service Principal vs Azure CLI

**Run 4 Failed:** Even after granting RBAC permissions, authentication still failed. The issue was that `kubelogin convert-kubeconfig -l azurecli` uses the Azure CLI session, but service principals authenticate differently in GitHub Actions.

**Resolution:** Switch to service principal authentication mode:
```yaml
- name: Install kubelogin
  run: |
    az aks install-cli
    kubelogin convert-kubeconfig -l spn \
      --client-id ${{ secrets.AZURE_CLIENT_ID }} \
      --client-secret ${{ secrets.AZURE_CLIENT_SECRET }}
  env:
    AAD_SERVICE_PRINCIPAL_CLIENT_ID: ${{ secrets.AZURE_CLIENT_ID }}
    AAD_SERVICE_PRINCIPAL_CLIENT_SECRET: ${{ secrets.AZURE_CLIENT_SECRET }}
```

This required adding `AZURE_CLIENT_ID` and `AZURE_CLIENT_SECRET` as separate GitHub secrets.

### 7. Missing File — Gitignore Pattern Too Broad

**Run 5 Failed:** Deploy step failed with:
```
error: the path "kubernetes/secret-provider-class.yaml" does not exist
```

The file existed locally but was never committed. Investigation revealed the `.gitignore` had:
```
*secret*
```

This pattern matched `secret-provider-class.yaml` even though it's a Kubernetes manifest, not an actual secret.

**Resolution:** Updated `.gitignore` to be more specific:
```gitignore
# Before (too broad)
*secret*

# After (specific)
**/secrets/
# Note: kubernetes/secret-provider-class.yaml is allowed (config, not secrets)
```

Then force-added and committed the file.

### 8. Workload Identity Failure — Placeholder Client ID

**Run 6 Failed:** Pods stuck in `ContainerCreating` with mount failures:
```
MountVolume.SetUp failed for volume "secrets-store":
AADSTS700016: Application with identifier 'placeholder' was not found
```

The `WORKLOAD_IDENTITY_CLIENT_ID` GitHub variable was set to `placeholder` because proper workload identity wasn't configured. The Kubernetes manifests referenced this for Key Vault CSI driver authentication.

**Resolution:** For this demo, I simplified the manifests to remove Key Vault CSI dependencies:
1. Removed `volumeMounts` and `volumes` for secrets-store
2. Removed `azure.workload.identity/use: "true"` label
3. Removed `serviceAccountName: app-workload-identity`
4. Removed secret environment variables from deployments
5. Updated workflow to skip `secret-provider-class.yaml`

This allowed the demo apps to run without full workload identity setup.

---

## Root Causes

| Issue | Root Cause |
|-------|------------|
| Git push denied | SSH key associated with different GitHub account |
| No ACR | Infrastructure module was never created |
| kubelogin not found | Azure RBAC AKS requires kubelogin, not pre-installed on runners |
| RBAC denied | Service principal lacked AKS RBAC role (separate from resource RBAC) |
| kubelogin auth failure | Used `azurecli` mode instead of `spn` mode for service principals |
| Missing manifest | `.gitignore` pattern `*secret*` blocked legitimate K8s config file |
| Pod mount failure | `WORKLOAD_IDENTITY_CLIENT_ID` set to placeholder, not real identity |

---

## Resolution Summary

1. **Git Authentication:** Used PAT for HTTPS push to personal account
2. **ACR Module:** Created `terraform/modules/acr/` and deployed registry
3. **GitHub Secrets:** Configured AZURE_CREDENTIALS, ACR credentials, and SP credentials
4. **kubelogin:** Install via `az aks install-cli` with `-l spn` mode
5. **AKS RBAC:** Granted "Azure Kubernetes Service RBAC Cluster Admin" to service principal
6. **Gitignore:** Removed overly broad `*secret*` pattern
7. **Simplified Demo:** Removed Key Vault CSI dependencies for basic demo

---

## Final Working Workflow

```yaml
- name: Azure Login
  uses: azure/login@v2
  with:
    creds: ${{ secrets.AZURE_CREDENTIALS }}

- name: Set AKS context
  uses: azure/aks-set-context@v4
  with:
    resource-group: ${{ env.AKS_RESOURCE_GROUP }}
    cluster-name: ${{ env.AKS_CLUSTER_NAME }}

- name: Install kubelogin
  run: |
    az aks install-cli
    kubelogin convert-kubeconfig -l spn \
      --client-id ${{ secrets.AZURE_CLIENT_ID }} \
      --client-secret ${{ secrets.AZURE_CLIENT_SECRET }}
  env:
    AAD_SERVICE_PRINCIPAL_CLIENT_ID: ${{ secrets.AZURE_CLIENT_ID }}
    AAD_SERVICE_PRINCIPAL_CLIENT_SECRET: ${{ secrets.AZURE_CLIENT_SECRET }}

- name: Deploy to AKS
  run: |
    kubectl apply -f kubernetes/namespace.yaml
    kubectl apply -f kubernetes/configmap.yaml
    kubectl apply -f kubernetes/backend-api/
    kubectl apply -f kubernetes/worker/
```

---

## Key Takeaways

1. **Azure RBAC for AKS is Separate:** Resource-level Contributor role doesn't grant kubectl access. AKS RBAC roles must be explicitly assigned.

2. **kubelogin Auth Modes Matter:** Service principals in CI/CD must use `-l spn` mode, not `-l azurecli`. The Azure CLI session context differs between local dev and GitHub Actions.

3. **Gitignore Patterns Need Care:** Broad patterns like `*secret*` can block legitimate configuration files. Use specific patterns or explicit negations.

4. **Workload Identity Requires Full Setup:** Using Key Vault CSI driver with workload identity requires:
   - Federated identity credential in Azure AD
   - Service account with proper annotations
   - Correct client ID in SecretProviderClass

   For demos, consider simplifying or using managed identity alternatives.

5. **Iterative Debugging is Normal:** Complex CI/CD pipelines often require multiple iterations. Each failure reveals a new layer of configuration requirements.

---

## Pipeline Run History

| Run | Commit | Result | Issue |
|-----|--------|--------|-------|
| 1 | Initial commit | Failed | No source code in repo |
| 2 | Add ACR + apps | Failed | kubelogin not installed |
| 3 | Add kubelogin action | Failed | Action doesn't exist |
| 4 | Use az aks install-cli | Failed | RBAC permission denied |
| 5 | Grant RBAC + wait | Failed | kubelogin azurecli mode wrong |
| 6 | Use spn mode | Failed | secret-provider-class.yaml missing |
| 7 | Fix gitignore + add file | Failed | Workload identity placeholder |
| 8 | Remove KV CSI deps | **Success** | Full pipeline working |

---

## Verification

```bash
# API endpoint responding
$ curl http://api.48.202.8.8.nip.io/api/
{"service":"backend-api","status":"healthy","version":"1.0.0"}

# Pods running with ACR images
$ kubectl get pods -n app -o jsonpath='{.items[*].spec.containers[*].image}'
aksplatformdevacr.azurecr.io/backend-api:e4c1246...
aksplatformdevacr.azurecr.io/worker:e4c1246...

# Worker processing
$ kubectl logs -n app -l app.kubernetes.io/name=worker --tail=3
INFO:__main__:Worker processing... (version: 1.0.0)
INFO:__main__:Worker processing... (version: 1.0.0)
INFO:__main__:Worker processing... (version: 1.0.0)
```
