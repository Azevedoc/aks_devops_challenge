# Azure AKS Deployment Troubleshooting Report

**Date:** 2026-01-14
**Issue:** AKS Cluster Deployment Failures on Free Azure Subscription
**Status:** Resolved

---

## Summary

Deploying an AKS cluster using Azure Verified Modules (AVM) on a free Azure subscription with $200 credit encountered multiple cascading failures. The root cause was that free Azure subscriptions have significant limitations not well-documented in AVM modules, including no availability zone support and region-specific VM SKU restrictions. Resolution required replacing the AVM AKS module with a direct `azurerm_kubernetes_cluster` resource and changing regions from eastus to westus2.

---

## Investigation Process

### 1. Initial Configuration Errors — Validating Terraform Setup

The first terraform plan revealed missing required variables. Since the user wanted to deploy on their personal Azure account, I needed to add subscription-specific configuration.

**Issues found:**
- Missing `subscription_id` variable in provider configuration
- Log retention set to 7 days (Azure minimum is 30)
- Private endpoints using dynamic `for_each` with unknown keys
- AKS module missing `tenant_id` for Azure RBAC
- Storage module using `count` with unknown values
- Output referring to sensitive values without marking

**Resolution:** Added variables with appropriate defaults and flags (`enable_private_endpoint`, `enable_rbac_assignment`) to control resource creation at plan time.

### 2. Availability Zone Restrictions — Understanding Free Subscription Limits

After fixing configuration, the first apply failed with:
```
AvailabilityZoneNotSupported: The requested VM size Standard_B2s is not available
in the current region for this subscription.
```

I initially thought this was a VM SKU issue and tried different regions (westeurope → northeurope → eastus) and VM sizes (B2s → D2as_v5), but the error persisted across all combinations.

**Key insight:** The error message mentioned "availability zones" even though I wasn't explicitly requesting them. Investigation revealed that Azure Verified Modules' `avm-ptn-aks-production` pattern **forces** availability zone configuration by design.

### 3. AVM Module Deep Dive — Identifying the Blocker

I examined the AVM AKS production module and found it hardcodes zone-redundant configurations:

```hcl
# AVM module forces zones configuration
zones = [1, 2, 3]  # Cannot be disabled
```

Free Azure subscriptions do not support availability zones regardless of region or VM SKU. The AVM production pattern is designed for production workloads and doesn't accommodate demo/free-tier scenarios.

**Decision:** Replace the AVM wrapper with a direct `azurerm_kubernetes_cluster` resource that allows zone configuration to be omitted entirely.

### 4. State Management Chaos — Dealing with Partial Applies

Switching from AVM to direct resource caused Terraform state drift. Some resources existed in Azure but not in state, others in state but deleted from Azure.

**State issues encountered:**
| Resource | Problem | Solution |
|----------|---------|----------|
| Storage Account | In state, deleted in Azure | `terraform state rm` |
| AKS (AVM) | Old AVM resources orphaned | `terraform state rm` (10 resources) |
| Key Vault | Soft-deleted, blocking recreation | `az keyvault purge` |
| VNet | Existed in Azure, not in state | `terraform import` |
| Storage Account | Recreated in Azure, not in state | `terraform import` |

### 5. VM SKU Regional Availability — Finding the Right Region

After fixing the AKS module, deployment still failed:
```
The agent pool VM size 'standard_b2s' is not available in location 'eastus'
for this subscription.
```

I used Azure CLI to investigate VM SKU availability:
```bash
az vm list-skus --location eastus --resource-type virtualMachines -o json | \
  python3 -c "import sys, json; data=json.load(sys.stdin); \
  print([x['name'] for x in data if 'D2' in x['name'] or 'B2' in x['name']])"
# Result: []  (empty - no basic VMs in eastus for this subscription)
```

Same query in westus2 returned available SKUs. The free subscription apparently had quota/SKU limitations specific to certain regions.

### 6. Final Region Migration — Bringing It All Together

Changing from eastus to westus2 triggered full resource recreation and more state drift issues:
- Key Vault blocked by soft-deleted vault with same name in eastus
- Storage account and VNet existed but not in state

**Resolution sequence:**
1. Purge soft-deleted Key Vault: `az keyvault purge --name aksplatformdevkv --location eastus`
2. Import VNet: `terraform import 'module.networking.module.vnet.azapi_resource.vnet' <resource_id>`
3. Import Storage Account: `terraform import 'module.storage.module.storage_account.azurerm_storage_account.this' <resource_id>`
4. Apply successfully

---

## Root Cause

**Primary:** Azure Verified Modules' AKS production pattern (`avm-ptn-aks-production`) enforces availability zones which are not available on free Azure subscriptions, regardless of region or VM SKU.

**Secondary:** Free Azure subscriptions have undocumented regional restrictions on VM SKU availability. Basic D-series and B-series VMs were not available in eastus but were available in westus2.

---

## Resolution

1. **Replaced AVM AKS module** with direct `azurerm_kubernetes_cluster` resource:
   - Removed zone configuration entirely
   - Added Key Vault secrets provider and OIDC issuer explicitly
   - Maintained Azure RBAC and CNI networking

2. **Changed region** from eastus to westus2 where basic VM SKUs are available

3. **Used Standard_B2s_v2** VM size (burstable, 2 vCPU, 4 GB RAM)

4. **Purged soft-deleted Key Vault** to allow recreation with same name in new region

5. **Imported existing resources** after partial applies to reconcile state

---

## Key Takeaways

1. **AVM Production Modules Assume Production Infrastructure**: The Azure Verified Modules production patterns are designed for real workloads with zone redundancy. They're not suitable for demos on free/trial subscriptions.

2. **Free Subscriptions Have Hidden Restrictions**: Beyond the documented $200 credit limit, free subscriptions have:
   - No availability zone support
   - Region-specific VM SKU restrictions (not consistently documented)
   - vCPU quotas (4 total regional vCPUs)

3. **Key Vault Soft-Delete Is Global**: Even when changing regions, Key Vault names are globally unique and soft-deleted vaults block recreation. Always purge before recreating.

4. **State Management Requires Discipline**: Partial applies and region changes create state drift. Keep track of:
   - Resources that exist in Azure but not state (need import)
   - Resources in state that were deleted (need state rm)
   - Soft-deleted resources (need purge before recreation)

5. **Test Region VM Availability Early**: Before committing to a region, verify VM SKU availability:
   ```bash
   az vm list-skus --location <region> --resource-type virtualMachines -o json | \
     python3 -c "import sys,json;d=json.load(sys.stdin);print([x['name'] for x in d if 'B2' in x['name']])"
   ```

---

## Final Configuration

| Setting | Value |
|---------|-------|
| Region | westus2 |
| VM Size | Standard_B2s_v2 |
| Kubernetes Version | 1.33 |
| Network Plugin | Azure CNI |
| Network Policy | Calico |
| Availability Zones | None (not available) |
| OIDC Issuer | Enabled |
| Key Vault Secrets Provider | Enabled |

**Resources Created:**
- Resource Group: aksplatform-dev-rg
- AKS Cluster: aksplatform-dev-aks
- VNet: aksplatform-dev-vnet (10.0.0.0/16)
- Key Vault: aksplatformdevkv
- Storage Account: aksplatformdevsa
- Log Analytics: aksplatform-dev-law
