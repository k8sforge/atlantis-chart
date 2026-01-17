# Atlantis Helm Chart

![Chart Releaser](https://github.com/k8sforge/atlantis-chart/actions/workflows/chart-releaser.yml/badge.svg)

A Helm chart for deploying Atlantis on Kubernetes. Atlantis automates Terraform workflows through pull requests.

---

## Overview

This is a **reusable Helm chart repository**. The chart is versioned and published so it can be referenced by other repositories that deploy Atlantis.

This chart wraps the official [Atlantis Helm chart](https://github.com/runatlantis/helm-charts) with sensible defaults and additional configurations including:

- **Intelligent Storage** - EBS/EFS auto-selection based on replica count
- **Configurable health checks** - Platform-agnostic health check configuration for ingress
- **Prometheus monitoring** - ServiceMonitor for metrics scraping (optional)
- **High availability** - PodDisruptionBudget for production deployments (optional)
- **Resource management** - Sensible resource defaults for Atlantis components

---

## Chart Details

- **Chart Name**: `atlantis`
- **Chart Version**: See [Chart.yaml](charts/atlantis/Chart.yaml#L5)
- **App Version**: `latest` (Atlantis image tag)
- **Dependencies**:
  - `atlantis` (v0.30.0) from `https://runatlantis.github.io/helm-charts`

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
  oci://ghcr.io/k8sforge/atlantis-chart/atlantis \
  --version 0.1.0
```

If the registry is private:

```bash
helm registry login ghcr.io
```

---

### Install via Helm Repository (GitHub Pages)

```bash
helm repo add atlantis https://k8sforge.github.io/atlantis-chart
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
- Prometheus Operator (optional, for ServiceMonitor support)
- Ingress controller (nginx, traefik, or platform-specific such as AWS ALB)

---

## Configuration

The following table lists the main configurable parameters:

| Parameter                                                  | Description                  | Default                |
| ---------------------------------------------------------- | ---------------------------- | ---------------------- |
| `replicaCount`                                             | Number of replicas (wrapper) | `1`                    |
| `atlantis.image.repository`                                | Atlantis image repository    | `runatlantis/atlantis` |
| `atlantis.image.tag`                                       | Atlantis image tag           | `latest`               |
| `atlantis.replicaCount`                                    | Replicas (official chart)    | `1`                    |
| `atlantis.service.type`                                    | Service type                 | `ClusterIP`            |
| `atlantis.service.port`                                    | Service port                 | `4141`                 |
| `atlantis.orgAllowlist`                                    | Repository allowlist pattern | `github.com/myorg/*`   |
| `atlantis.ingress.enabled`                                 | Enable ingress               | `false`                |
| `atlantis.ingress.ingressClassName`                        | Ingress class name           | `""`                   |
| `atlantis.resources.requests.memory`                       | Memory request               | `512Mi`                |
| `atlantis.resources.requests.cpu`                          | CPU request                  | `100m`                 |
| `atlantis.resources.limits.memory`                         | Memory limit                 | `1Gi`                  |
| `atlantis.resources.limits.cpu`                            | CPU limit                    | `100m`                 |

See [values.yaml](charts/atlantis/values.yaml) for the full configuration.

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
atlantis:
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
atlantis:
  githubApp:
    id: "123456"
    key: |
      -----BEGIN RSA PRIVATE KEY-----
      ...
      -----END RSA PRIVATE KEY-----
    installationId: "78901234"
  github:
    webhookSecret: "your-webhook-secret"
```

---

## Environment Variables

You can configure additional environment variables for Atlantis using the `atlantis.environment` section:

```yaml
atlantis:
  environment:
    ATLANTIS_GH_USER: "your-github-user"
    ATLANTIS_GH_TOKEN: "your-github-token"
    ATLANTIS_DISABLE_APPLY_ALL: "true"
    ATLANTIS_LOG_LEVEL: "debug"
  orgAllowlist: "github.com/yourorg/*"
```

**Important**: Environment variables must be configured under the `atlantis:` section to be properly passed to the underlying Atlantis pods.

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

## GitHub App Secrets Support

The wrapper chart supports injecting GitHub App credentials from Kubernetes secrets using the official chart's `environmentSecrets` feature. This allows you to use secret management operators (e.g., Bitwarden Secrets Manager) without exposing secrets in Helm values.

### Configuring GitHub App Secrets

1. **Enable `githubAppSecrets` in your values:**

```yaml
githubAppSecrets:
  enabled: true
  secretName: "dev-github-app-secrets"  # Your Kubernetes secret name
  keys:
    appId: "value"          # Key in secret for App ID
    appKey: "value"         # Key in secret for private key
    webhookSecret: "value"  # Key in secret for webhook secret
```

1. **Configure `atlantis.environmentSecrets` and `atlantis.environment`:**

Since Helm doesn't support dynamic value merging, you need to set these in your `atlantis:` section:

```yaml
atlantis:
  environmentSecrets:
    - name: "dev-github-app-secrets"  # Must match githubAppSecrets.secretName
      keys:
        - "value"  # Must match githubAppSecrets.keys.appId
        - "value"  # Must match githubAppSecrets.keys.appKey
        - "value"  # Must match githubAppSecrets.keys.webhookSecret

  environment:
    ATLANTIS_GH_APP_ID: "$value"           # References key from secret
    ATLANTIS_GH_APP_KEY: "$value"           # References key from secret
    ATLANTIS_GH_WEBHOOK_SECRET: "$value"    # References key from secret
```

**Note**: The `$` prefix in environment variable values references keys from `environmentSecrets`. The key names must match the keys defined in your Kubernetes secret.

### Helper Templates

The chart provides helper template functions you can use:

- `{{ include "atlantis.githubAppSecrets.envSecrets" . }}` - Generates `environmentSecrets` configuration
- `{{ include "atlantis.githubAppSecrets.env" . }}` - Generates `environment` variable mappings

However, these cannot be used directly in `values.yaml` (Helm doesn't support template syntax in values files). They are provided for reference or if you're generating values programmatically.

### Migration from Manual Patching

If you're currently using Terraform or kubectl to patch the StatefulSet:

1. Enable `githubAppSecrets` in Helm values
2. Configure `atlantis.environmentSecrets` and `atlantis.environment` as shown above
3. Remove your `kubectl_manifest.atlantis_env_patch` resource
4. Remove `ignoreDifferences` for StatefulSet env from ArgoCD Application

This approach uses the official chart's built-in features - no patches required.

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
    repository: https://k8sforge.github.io/atlantis-chart
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

### Value Pass-Through Issues

If environment variables or configuration are not appearing in Atlantis pods:

1. **Check Value Structure**: Ensure Atlantis-specific configuration is under the `atlantis:` section:

```yaml
# ❌ Wrong - will not be passed to Atlantis
environment:
  ATLANTIS_GH_USER: "user"

# ✅ Correct - properly passed to subchart
atlantis:
  environment:
    ATLANTIS_GH_USER: "user"
```

1. **Verify ConfigMap**: Check that the official chart's ConfigMap contains your values:

```bash
kubectl get configmap <release-name>-atlantis -o yaml
```

1. **Check Pod Environment**: Verify environment variables in the running pod:

```bash
kubectl exec <pod-name> -- env | grep ATLANTIS
```

---

## License

MIT License. See [LICENSE](LICENSE) for details.
