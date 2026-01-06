# Atlantis Helm Chart Examples

This document provides practical examples for deploying Atlantis with the enhanced k8sforge chart.

## Table of Contents

- [Quick Start](#quick-start)
- [Installation Methods](#installation-methods)
- [Basic Configuration](#basic-configuration)
- [Advanced Deployment Strategies](#advanced-deployment-strategies)
- [Enterprise Features](#enterprise-features)
- [Production Examples](#production-examples)
- [Troubleshooting](#troubleshooting)

---

## Quick Start

### Prerequisites

```bash
# Add the repository
helm repo add atlantis https://k8sforge.github.io/atlantis-chart
helm repo update
```

### Basic Installation

```bash
# Install with minimal configuration
helm install my-atlantis atlantis/atlantis \
  --set atlantis.orgAllowlist="github.com/myorg/*" \
  --set atlantis.github.user="atlantis-bot" \
  --set atlantis.github.token="ghp_xxxxxxxxxxxx"
```

---

## Installation Methods

### From Helm Repository

```bash
# Install latest version
helm install my-atlantis atlantis/atlantis

# Install specific version
helm install my-atlantis atlantis/atlantis --version 0.1.0
```

### From Source

```bash
# Clone and install from source
git clone https://github.com/k8sforge/atlantis-chart.git
cd atlantis-chart
helm install my-atlantis charts/atlantis
```

### With Custom Values File

```bash
# Create values file
cat > values.yaml <<EOF
replicaCount: 2
atlantis:
  orgAllowlist: "github.com/myorg/*"
  github:
    user: "atlantis-bot"
    token: "ghp_xxxxxxxxxxxx"
    secret: "webhook-secret"
EOF

# Install with values
helm install my-atlantis atlantis/atlantis -f values.yaml
```

---

## Basic Configuration

### GitHub Authentication

**Personal Access Token:**

```yaml
atlantis:
  github:
    user: "atlantis-bot"
    token: "ghp_xxxxxxxxxxxx"
    secret: "webhook-secret"
  orgAllowlist: "github.com/myorg/*"
```

**GitHub App (Recommended):**

```yaml
atlantis:
  githubApp:
    id: "123456"
    installationId: "78901234"
    key: |
      -----BEGIN PRIVATE KEY-----
      MIIEpAIBAAKCAQEA...
      -----END PRIVATE KEY-----
  github:
    secret: "webhook-secret"
  orgAllowlist: "github.com/myorg/*"
```

### Basic Ingress Setup

```yaml
atlantis:
  ingress:
    enabled: true
    ingressClassName: "nginx"
    host: atlantis.example.com
    annotations:
      cert-manager.io/cluster-issuer: "letsencrypt-prod"
```

---

## Advanced Deployment Strategies

### Standard Kubernetes Deployment

```yaml
deployment:
  type: deployment
  strategy: rollingUpdate
  rollingUpdate:
    maxSurge: "25%"
    maxUnavailable: "25%"
```

### Argo Rollouts - Blue-Green

```yaml
deployment:
  type: rollout
  strategy: blueGreen
  autoPromotionEnabled: false
  scaleDownDelaySeconds: 30
```

**Manage rollout:**

```bash
# Check status
kubectl argo rollouts get rollout my-atlantis

# Promote new version
kubectl argo rollouts promote my-atlantis
```

### Argo Rollouts - Canary

```yaml
deployment:
  type: rollout
  strategy: canary
  canary:
    steps:
      - setWeight: 20
      - pause: {}
      - setWeight: 50
      - pause: { duration: 30s }
      - setWeight: 80
      - pause: { duration: 30s }
```

---

## Enterprise Features

### Intelligent Persistent Storage

**Automatic Selection (Recommended):**

```yaml
# Single replica = EBS (ReadWriteOnce)
# Multi-replica = EFS (ReadWriteMany)
persistence:
  enabled: true
  ebs:
    storageClass: "gp3"
    size: 20Gi
  efs:
    storageClass: "efs-sc"
    size: 50Gi
```

**Manual Override:**

```yaml
persistence:
  enabled: true
  storageClass: "custom-sc"
  size: 100Gi
  accessModes: ["ReadWriteMany"]
```

### Prometheus Monitoring

```yaml
monitoring:
  serviceMonitor:
    enabled: true
    interval: "30s"
    scrapeTimeout: "10s"
    labels:
      release: prometheus
```

### High Availability

```yaml
replicaCount: 3
podDisruptionBudget:
  enabled: true
  minAvailable: 2
```

### Health Checks

```yaml
healthCheck:
  enabled: true
  path: "/healthz"
  protocol: "HTTP"
```

---

## Production Examples

### AWS EKS with ALB

```yaml
# aws-production.yaml
replicaCount: 2

atlantis:
  githubApp:
    id: "123456"
    installationId: "78901234"
  github:
    secret: "webhook-secret"

  orgAllowlist: "github.com/myorg/*"

  ingress:
    enabled: true
    ingressClassName: "alb"
    host: atlantis.company.com
    annotations:
      alb.ingress.kubernetes.io/scheme: internet-facing
      alb.ingress.kubernetes.io/target-type: ip
      alb.ingress.kubernetes.io/certificate-arn: "arn:aws:acm:region:account:certificate/cert-id"

persistence:
  enabled: true
  efs:
    storageClass: "efs-sc"
    size: 50Gi

monitoring:
  serviceMonitor:
    enabled: true

  resources:
    requests:
      memory: "512Mi"
      cpu: "200m"
    limits:
      memory: "1Gi"
      cpu: "500m"

podDisruptionBudget:
  enabled: true
  minAvailable: 1
```

**Deploy:**

```bash
# Create GitHub App secret
kubectl create secret generic my-atlantis-secrets \
  --from-literal=github-app-id='123456' \
  --from-file=github-app-key=./private-key.pem \
  --from-literal=github-app-installation-id='78901234' \
  --from-literal=webhook-secret='webhook-secret'

# Deploy
helm install atlantis atlantis/atlantis -f aws-production.yaml
```

### GKE with NGINX

```yaml
# gke-production.yaml
replicaCount: 2

atlantis:
  github:
    user: "atlantis-bot"
    token: "ghp_xxxxxxxxxxxx"
    secret: "webhook-secret"

  orgAllowlist: "github.com/myorg/*"

  ingress:
    enabled: true
    ingressClassName: "nginx"
    host: atlantis.company.com
    annotations:
      cert-manager.io/cluster-issuer: "letsencrypt-prod"
      nginx.ingress.kubernetes.io/ssl-redirect: "true"

  resources:
    requests:
      memory: "512Mi"
      cpu: "200m"
    limits:
      memory: "1Gi"
      cpu: "500m"

persistence:
  enabled: true
  storageClass: "ssd"
  size: 50Gi
  accessModes: ["ReadWriteMany"]

monitoring:
  serviceMonitor:
    enabled: true
```

### Multi-Environment Setup

```yaml
# base-values.yaml (shared)
atlantis:
  orgAllowlist: "github.com/myorg/*"
  resources:
    requests:
      memory: "256Mi"
      cpu: "100m"

monitoring:
  serviceMonitor:
    enabled: true
```

```yaml
# production-values.yaml
replicaCount: 3
persistence:
  enabled: true
podDisruptionBudget:
  enabled: true
  minAvailable: 2
```

```yaml
# staging-values.yaml
replicaCount: 1
persistence:
  enabled: false
```

**Deploy:**

```bash
# Production
helm install atlantis-prod atlantis/atlantis \
  -f base-values.yaml -f production-values.yaml \
  --namespace production

# Staging
helm install atlantis-staging atlantis/atlantis \
  -f base-values.yaml -f staging-values.yaml \
  --namespace staging
```

---

## Troubleshooting

### Common Issues

**Check Pod Status:**

```bash
kubectl get pods -l app.kubernetes.io/name=atlantis
kubectl logs -l app.kubernetes.io/name=atlantis
```

**Validate Configuration:**

```bash
# Test template rendering
helm template my-atlantis atlantis/atlantis -f values.yaml

# Lint chart
helm lint atlantis/atlantis

# Dry run installation
helm install my-atlantis atlantis/atlantis --dry-run --debug
```

**Check Resources:**

```bash
# Service and Ingress
kubectl get svc,ingress -l app.kubernetes.io/name=atlantis

# Persistent Storage
kubectl get pvc -l app.kubernetes.io/name=atlantis

# Argo Rollouts
kubectl argo rollouts get rollout my-atlantis
```

### Configuration Validation

**GitHub Webhook:**

- URL: `https://your-atlantis-url/events`
- Secret: Must match `github.secret` value
- Events: `Pull requests`, `Issue comments`, `Push`

**Storage Requirements:**

- Single replica: Any storage class with `ReadWriteOnce`
- Multi-replica: Requires `ReadWriteMany` (EFS, NFS, etc.)

**Resource Requirements:**

- Minimum: 256Mi memory, 100m CPU
- Recommended: 512Mi memory, 200m CPU per replica

---

## Next Steps

1. **Configure GitHub Webhook** → Point to your Atlantis URL
2. **Test with Sample PR** → Verify Terraform automation
3. **Monitor Deployment** → Check logs and metrics
4. **Scale as Needed** → Adjust replicas and resources

For more information, see the [main documentation](README.md).
