# Atlantis Helm Chart

![Chart Releaser](https://github.com/k8sforge/atlantis-chart/actions/workflows/chart-releaser.yml/badge.svg)

An **enhanced wrapper** around the [official Atlantis Helm chart](https://github.com/runatlantis/helm-charts) that adds enterprise-grade features for production deployments. Atlantis automates Terraform workflows through pull requests.

---

## 🎯 **Wrapper Chart Architecture**

This chart extends the **official Atlantis chart (v5.24.1)** as a dependency, providing:

✅ **Official Chart Benefits:**

- Community-maintained and regularly updated
- Production-tested and stable
- Full Atlantis feature compatibility

✅ **Enhanced Features:**

- **Argo Rollouts** support (Blue-Green, Canary, Rolling Update)
- **Intelligent Storage** (EBS/EFS auto-selection based on replica count)
- **Enhanced Monitoring** (ServiceMonitor, platform-agnostic health checks)
- **High Availability** (PodDisruptionBudget, multi-replica validation)

---

## Overview

This is a **reusable enhanced Helm chart repository**.
The chart wraps the official Atlantis chart and adds advanced features for enterprise deployments.

---

## Chart Details

- **Chart Name**: `atlantis`
- **Chart Version**: `0.1.0`
- **App Version**: `latest` (Atlantis image tag)

---

## Distribution

This chart is published in two formats:

- **OCI (ghcr.io)** – modern, registry-based installs
- **Helm repository (GitHub Pages)** – classic `helm repo add` workflow

Both distributions publish the same chart versions.

---

## Quick Start

### Install via OCI (recommended)

```bash
helm install my-atlantis \
  oci://ghcr.io/k8sforge/atlantis-charts/atlantis \
  --version 0.1.0
```

If the registry is private:

```bash
helm registry login ghcr.io
```

---

### Install via Helm Repository (GitHub Pages)

```bash
helm repo add atlantis https://k8sforge.github.io/atlantis-charts
helm repo update

helm install my-atlantis atlantis/atlantis --version 0.1.0
```

---

### Install from Source (local development)

```bash
helm install my-atlantis .
```

---

## Prerequisites

- Kubernetes 1.20+
- `kubectl` configured
- Helm 3.x
- **Official Atlantis Chart Repository** (automatically added as dependency)
- Argo Rollouts controller (optional, for Blue-Green/Canary deployments)
- Prometheus Operator (optional, for ServiceMonitor support)
- Ingress controller (nginx, traefik, or platform-specific such as AWS ALB)

---

## Configuration

The following table lists the main configurable parameters:

| Parameter                                                  | Description                  | Default                |
| ---------------------------------------------------------- | ---------------------------- | ---------------------- |
| `image.repository`                                         | Atlantis image repository    | `runatlantis/atlantis` |
| `image.tag`                                                | Atlantis image tag           | `latest`               |
| `replicaCount`                                             | Number of replicas           | `1`                    |
| `service.type`                                             | Service type                 | `ClusterIP`            |
| `service.port`                                             | Service port                 | `4141`                 |
| `deployment.type`                                          | Deployment type              | `rollout`              |
| `deployment.strategy`                                      | Rollout strategy             | `blueGreen`            |
| `deployment.autoPromotionEnabled`                          | Auto-promote on deployment   | `false`                |
| `atlantis.repoAllowlist`                                   | Repository allowlist pattern | `github.com/*`         |
| `ingress.enabled`                                          | Enable ingress               | `true`                 |
| `ingress.ingressClassName`                                 | Ingress class name           | `""`                   |
| `resources.requests.memory`                                | Memory request               | `256Mi`                |
| `resources.requests.cpu`                                   | CPU request                  | `100m`                 |
| `resources.limits.memory`                                  | Memory limit                 | `512Mi`                |
| `resources.limits.cpu`                                     | CPU limit                    | `500m`                 |
| See [values.yaml](values.yaml) for the full configuration. |                              |                        |

---

## Health Checks

Health checks can be enabled to automatically add health check annotations to the ingress. This is platform-agnostic and works with any ingress controller.

### Enable Health Checks

```yaml
healthCheck:
  enabled: true
  path: "/healthz"
  protocol: "HTTP"
  port: "traffic-port"
```

When enabled, health check annotations are automatically added to the ingress. You can override or add platform-specific annotations in `ingress.annotations`.

### Platform-Specific Examples

**AWS ALB:**

```yaml
healthCheck:
  enabled: true
  path: "/healthz"
ingress:
  annotations:
    alb.ingress.kubernetes.io/healthcheck-path: "/healthz"
    alb.ingress.kubernetes.io/healthcheck-protocol: "HTTP"
```

**NGINX:**

```yaml
healthCheck:
  enabled: true
  path: "/healthz"
ingress:
  annotations:
    nginx.ingress.kubernetes.io/health-check-path: "/healthz"
```

---

## Prometheus Monitoring

Enable ServiceMonitor for Prometheus metrics scraping:

```yaml
monitoring:
  serviceMonitor:
    enabled: true
    interval: "30s"
    scrapeTimeout: "10s"
    labels: {}
```

### Requirements

- Prometheus Operator must be installed in the cluster
- ServiceMonitor CRD must be available

### Verify ServiceMonitor

```bash
kubectl get servicemonitor -n <namespace>
```

---

## High Availability (PodDisruptionBudget)

Enable PodDisruptionBudget to ensure minimum availability during voluntary disruptions:

```yaml
podDisruptionBudget:
  enabled: true
  minAvailable: 1
  # Alternative: use maxUnavailable instead
  # maxUnavailable: 1
```

This prevents all Atlantis pods from being evicted simultaneously during node drains or updates.

---

## Persistent Storage

Enable persistent storage for Terraform provider/module caching. This significantly improves performance by avoiding re-downloading providers on every pod restart.

### Benefits

- **Faster Plan/Apply Operations**: Cached providers mean faster Terraform operations
- **Cost Savings**: Less network bandwidth usage
- **Better User Experience**: Reduced wait times for Terraform operations

### Enable Persistent Storage

The chart automatically selects optimal storage based on replica count:

```yaml
persistence:
  enabled: true
  # Automatic selection:
  # replicaCount=1: Uses ebs.storageClass (ReadWriteOnce)
  # replicaCount>1: Uses efs.storageClass (ReadWriteMany)
  ebs:
    storageClass: "gp3"
    size: 10Gi
  efs:
    storageClass: "efs-sc"
    size: 50Gi
```

### Manual Overrides

```yaml
persistence:
  enabled: true
  storageClass: "custom-sc"      # Override auto-selection
  size: "20Gi"                   # Override auto-selection
  accessModes: ["ReadWriteMany"] # Override auto-selection
  existingClaim: "my-pvc"        # Use existing PVC
```

### Automatic Storage Selection

- **Single replica** (`replicaCount: 1`): EBS storage with `ReadWriteOnce`
- **Multi-replica** (`replicaCount > 1`): EFS storage with `ReadWriteMany`
- **Validation**: Chart prevents incompatible configurations
- **Benefits**: Optimal performance and compatibility without manual configuration

### Verify Persistent Volume

```bash
kubectl get pvc -n <namespace>
kubectl get pv
```

---

## Authentication

Atlantis requires GitHub authentication.

### Option 1: GitHub Personal Access Token

```yaml
github:
  user: "your-username"
  token: "ghp_your_token"
  webhookSecret: "your-webhook-secret"
```

**Required scopes:**

- `repo`
- `admin:repo_hook`
- `write:repo_hook`

---

### Option 2: GitHub App (recommended for organizations)

```yaml
github:
  app:
    id: "123456"
    key: |
      -----BEGIN RSA PRIVATE KEY-----
      ...
      -----END RSA PRIVATE KEY-----
    installationId: "78901234"
  webhookSecret: "your-webhook-secret"
```

---

## Secrets Management

The chart expects a Kubernetes Secret named:

```plaintext
<release-name>-secrets
```

### Required keys

**Personal Access Token:**

- `github-user`
- `github-token`
- `webhook-secret`

**GitHub App:**

- `github-app-id`
- `github-app-key`
- `github-app-installation-id`
- `webhook-secret`

Example:

```bash
kubectl create secret generic my-atlantis-secrets \
  --from-literal=github-user='your-username' \
  --from-literal=github-token='ghp_your_token' \
  --from-literal=webhook-secret='your-secret' \
  --namespace=default
```

---

## Deployment Strategies

This chart supports three deployment types:

### 1. Standard Kubernetes Deployment

Use standard Kubernetes Deployment with rolling updates (no Argo Rollouts required):

```yaml
deployment:
  type: deployment
```

**Benefits:**

- No additional dependencies
- Simple and straightforward
- Standard Kubernetes rolling update behavior

### 2. Argo Rollouts - Rolling Update

Use Argo Rollouts with standard rolling update strategy:

```yaml
deployment:
  type: rollout
  strategy: rollingUpdate
  rollingUpdate:
    maxSurge: "25%"
    maxUnavailable: "25%"
```

**Benefits:**

- Enhanced rollout management
- Better observability
- Rollback capabilities

### 3. Argo Rollouts - Blue-Green

Use Argo Rollouts with blue-green deployment:

```yaml
deployment:
  type: rollout
  strategy: blueGreen
  autoPromotionEnabled: false
  scaleDownDelaySeconds: 30
```

**Features:**

- **Active Service** receives production traffic
- **Preview Service** exposes the new version
- **Manual promotion** by default (set `autoPromotionEnabled: true` for automatic)

**Promote a rollout:**

```bash
kubectl argo rollouts promote <release-name>-atlantis -n <namespace>
```

### 4. Argo Rollouts - Canary

Use Argo Rollouts with canary deployment:

```yaml
deployment:
  type: rollout
  strategy: canary
  canary:
    steps:
      - setWeight: 20
      - pause: {}
      - setWeight: 40
      - pause: { duration: 10s }
      - setWeight: 60
      - pause: { duration: 10s }
      - setWeight: 80
      - pause: { duration: 10s }
```

**Features:**

- Gradual traffic shift
- Configurable steps and pauses
- Optional analysis for automated promotion

**Check rollout status:**

```bash
kubectl argo rollouts get rollout <release-name>-atlantis -n <namespace>
```

---

## Using This Chart from Another Repository (Repo B Pattern)

### Example dependency

```yaml
apiVersion: v2
name: my-deployment
type: application
version: 1.0.0

dependencies:
  - name: atlantis
    version: 0.1.0
    repository: https://k8sforge.github.io/atlantis-charts
```

Then:

```bash
helm dependency update
helm upgrade --install my-atlantis . -f values.yaml
```

> Note: Helm 3.8+ supports OCI-based dependencies, but classic repositories are shown here for maximum compatibility.

---

## Versioning and Releases

This chart follows semantic versioning.

To release a new version:

```bash
git tag v0.2.0
git push --tags
```

GitHub Actions will automatically publish the chart to:

- **GHCR (OCI)**
- **GitHub Pages (Helm repo)**

---

## Development

### Lint

```bash
helm lint .
```

### Dry-run

```bash
helm install my-atlantis . --dry-run --debug
```

### Render templates

```bash
helm template my-atlantis . -f values.yaml
```

---

## Troubleshooting

### Check Pod Status

```bash
kubectl get pods -l app.kubernetes.io/name=atlantis
kubectl logs -l app.kubernetes.io/name=atlantis
```

### Check Service

```bash
kubectl get svc -l app.kubernetes.io/name=atlantis
```

### Check Ingress

```bash
kubectl get ingress -l app.kubernetes.io/name=atlantis
kubectl describe ingress <release-name>-atlantis-ingress
```

### Check Argo Rollouts

```bash
kubectl argo rollouts get rollout <release-name>-atlantis
```

### Check ServiceMonitor

```bash
kubectl get servicemonitor -l app.kubernetes.io/name=atlantis
```

### Check PodDisruptionBudget

```bash
kubectl get poddisruptionbudget -l app.kubernetes.io/name=atlantis
```

### Check Persistent Volume

```bash
kubectl get pvc -l app.kubernetes.io/name=atlantis
```

---

## License

MIT License. See [LICENSE](LICENSE) for details.
