# Technical Challenge – Cloud / DevOps Engineer

## Context
Your company runs a cloud-hosted application composed of one backend API and one
worker/background service. The platform runs on Azure and is standardizing infrastructure and
deployment practices using Infrastructure as Code (IaC), Kubernetes, and CI/CD automation.

## Objectives

### 1. Infrastructure & Cloud Design
Design a basic but robust architecture on Azure including AKS, networking (VNet/Subnets), ingress
approach and high availability considerations. Explain key decisions.

### 2. Infrastructure as Code (IaC)
Provide a Terraform sample that provisions AKS, networking basics, and one supporting resource
(e.g., Storage Account or Azure Monitor). Focus on structure and clarity rather than completeness.

### 3. Application Deployment
Deploy one service to Kubernetes using Helm or Kubernetes manifests, including Deployment,
Service, Ingress, resource requests/limits, and handling of configuration and secrets.

### 4. Automation & CI/CD (Conceptual)
Describe a CI/CD pipeline covering build, test, image publishing, and deployment to Kubernetes.
Mention tools you would typically use (e.g., GitHub Actions, Azure DevOps).

### 5. Observability & Operations
Explain how logs, metrics, and basic alerting would be handled in this platform. Mention tools you
are familiar with (e.g., Prometheus, Grafana, ELK, Azure Monitor).

### 6. Security & Best Practices
Describe your approach to IAM/RBAC, network security, secret management, and basic
container/image security practices.


## Deliverables

- README.md explaining the architecture and key decisions
- Terraform code sample
- Kubernetes manifests or Helm chart for one service
- Optional simple architecture diagram