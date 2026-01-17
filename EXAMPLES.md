# Atlantis Helm Chart - Examples

This document provides practical examples for deploying Atlantis using this wrapper chart.

## Table of Contents

- [Quick Start](#quick-start)
- [Installation Methods](#installation-methods)
- [Basic Configuration](#basic-configuration)
- [Authentication](#authentication)
- [Enterprise Features](#enterprise-features)
- [Production Examples](#production-examples)
- [Troubleshooting](#troubleshooting)

## Quick Start

### Example 1: Minimal Installation (Official Chart Only)

This example uses the official Atlantis chart with no enhancements - identical to installing the official chart directly.

```yaml
# minimal-values.yaml
atlantis:
  orgAllowlist: "github.com/myorg/*"

  github:
    user: "atlantis-bot"
    token: "ghp_xxxxxxxxxxxxx"
    secret: "webhook-secret-here"
```

```bash
helm install atlantis k8sforge/atlantis -f minimal-values.yaml
```

**What this creates:**

- Standard Kubernetes Deployment (from official chart)
- Service and Ingress (if configured)
- ConfigMaps and Secrets for Atlantis

**All enhancement features are disabled**, so this behaves exactly like the official chart.

## Installation Methods

### From Helm Repository

```bash
# Add repository
helm repo add k8sforge https://k8sforge.github.io/charts
helm repo update

# Install with custom values
helm install atlantis k8sforge/atlantis -f values.yaml

# Install in specific namespace
helm install atlantis k8sforge/atlantis -n atlantis --create-namespace -f values.yaml
```

### From OCI Registry

```bash
helm install atlantis oci://ghcr.io/k8sforge/charts/atlantis \
  --version 0.2.0 \
  -f values.yaml
```

### From Source

```bash
git clone https://github.com/k8sforge/atlantis-chart.git
cd atlantis-chart

# Update dependencies
helm dependency update charts/atlantis

# Install
helm install atlantis ./charts/atlantis -f values.yaml
```

## Basic Configuration

### Example 2: Basic with Ingress

```yaml
# basic-ingress-values.yaml
atlantis:
  orgAllowlist: "github.com/myorg/*"

  github:
    user: "atlantis-bot"
    token: "ghp_xxxxxxxxxxxxx"
    secret: "webhook-secret"

  ingress:
    enabled: true
    ingressClassName: "nginx"
    host: "atlantis.example.com"
    annotations:
      cert-manager.io/cluster-issuer: "letsencrypt-prod"
    tls:
      - secretName: atlantis-tls
        hosts:
          - atlantis.example.com

  resources:
    limits:
      memory: "2Gi"
      cpu: "1000m"
    requests:
      memory: "1Gi"
      cpu: "500m"
```

### Example 3: Multiple Replicas

```yaml
# multi-replica-values.yaml
orgAllowlist: "github.com/myorg/*"
replicaCount: 3

github:
  user: "atlantis-bot"
  token: "ghp_xxxxxxxxxxxxx"
  secret: "webhook-secret"

# Enable pod anti-affinity for HA
affinity:
  podAntiAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        podAffinityTerm:
          labelSelector:
            matchExpressions:
              - key: app.kubernetes.io/name
                operator: In
                values:
                  - atlantis
          topologyKey: kubernetes.io/hostname
```

## Authentication

### Example 4: GitHub Personal Access Token

```yaml
# github-pat-values.yaml
orgAllowlist: "github.com/myorg/*"

github:
  user: "atlantis-bot"
  token: "ghp_xxxxxxxxxxxxx"  # Personal Access Token with repo scope
  secret: "your-webhook-secret-here"

# Optional: Set Atlantis URL for PR comments
atlantisUrl: "https://atlantis.example.com"
```

**Required GitHub PAT permissions:**

- `repo` (full control of private repositories)
- `admin:repo_hook` (write access to webhook configuration)

### Example 5: GitHub App (Recommended)

```yaml
# github-app-values.yaml
orgAllowlist: "github.com/myorg/*"

githubApp:
  id: "123456"
  slug: "my-atlantis-app"
  key: |
    -----BEGIN RSA PRIVATE KEY-----
    MIIEpAIBAAKCAQEA... (your private key here)
    ...
    -----END RSA PRIVATE KEY-----

atlantisUrl: "https://atlantis.example.com"
```

**GitHub App required permissions:**

- Repository permissions:
  - Contents: Read & Write
  - Issues: Read & Write
  - Pull Requests: Read & Write
  - Webhooks: Read & Write
- Subscribe to events:
  - Pull request
  - Push
  - Issue comment
  - Pull request review
  - Pull request review comment

## Enterprise Features

### Example 9: Persistent Storage with EBS (Single Replica)

For single-replica deployments, uses EBS for optimal performance.

```yaml
# ebs-storage-values.yaml
orgAllowlist: "github.com/myorg/*"
replicaCount: 1

github:
  user: "atlantis-bot"
  token: "ghp_xxxxxxxxxxxxx"
  secret: "webhook-secret"

# Enable enhanced storage
enhancedStorage:
  enabled: true
  ebs:
    storageClass: "gp3"  # AWS EBS GP3 storage class
    size: 20Gi

# Alternatively, use explicit configuration
# enhancedStorage:
#   enabled: true
#   storageClass: "gp3"
#   size: 20Gi
#   accessModes:
#     - ReadWriteOnce
```

### Example 10: Persistent Storage with EFS (Multi-Replica)

For multi-replica deployments, uses EFS for shared access.

```yaml
# efs-storage-values.yaml
orgAllowlist: "github.com/myorg/*"
replicaCount: 3

github:
  user: "atlantis-bot"
  token: "ghp_xxxxxxxxxxxxx"
  secret: "webhook-secret"

# Enable enhanced storage (auto-selects EFS for multi-replica)
enhancedStorage:
  enabled: true
  efs:
    storageClass: "efs-sc"  # EFS storage class
    size: 50Gi

# EFS CSI Driver must be installed:
# kubectl apply -k "github.com/kubernetes-sigs/aws-efs-csi-driver/deploy/kubernetes/overlays/stable/?ref=release-1.5"
```

### Example 11: Prometheus Monitoring

Enable Prometheus ServiceMonitor for metrics scraping.

```yaml
# monitoring-values.yaml
orgAllowlist: "github.com/myorg/*"

github:
  user: "atlantis-bot"
  token: "ghp_xxxxxxxxxxxxx"
  secret: "webhook-secret"

# Enable ServiceMonitor
enhancedMonitoring:
  serviceMonitor:
    enabled: true
    interval: "30s"
    scrapeTimeout: "10s"
    labels:
      prometheus: kube-prometheus
      release: prometheus-operator

# Prometheus Operator must be installed:
# helm install prometheus prometheus-community/kube-prometheus-stack
```

### Example 12: High Availability with PodDisruptionBudget

Protect against voluntary disruptions.

```yaml
# ha-values.yaml
orgAllowlist: "github.com/myorg/*"
replicaCount: 3

github:
  user: "atlantis-bot"
  token: "ghp_xxxxxxxxxxxxx"
  secret: "webhook-secret"

# Enable PodDisruptionBudget
enhancedHA:
  podDisruptionBudget:
    enabled: true
    minAvailable: 2  # Always keep 2 pods running

# Alternative: use maxUnavailable
# enhancedHA:
#   podDisruptionBudget:
#     enabled: true
#     maxUnavailable: 1  # Allow max 1 pod to be disrupted
```

## Production Examples

### Example 13: Complete Production Setup

Full production-ready configuration with all features.

```yaml
# production-values.yaml

# Basic Configuration
orgAllowlist: "github.com/myorg/*"
replicaCount: 3
logLevel: "info"
atlantisUrl: "https://atlantis.example.com"

# GitHub App Authentication
githubApp:
  id: "123456"
  slug: "myorg-atlantis"
  key: |
    -----BEGIN RSA PRIVATE KEY-----
    ... (private key)
    -----END RSA PRIVATE KEY-----

# Image Configuration
image:
  repository: runatlantis/atlantis
  tag: "v0.27.0"  # Pin specific version
  pullPolicy: IfNotPresent

# Service Configuration
service:
  type: ClusterIP
  port: 4141
  annotations:
    prometheus.io/scrape: "true"
    prometheus.io/port: "4141"

# Ingress with TLS
ingress:
  enabled: true
  ingressClassName: "nginx"
  host: "atlantis.example.com"
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
  tls:
    - secretName: atlantis-tls
      hosts:
        - atlantis.example.com

# Resource Management
resources:
  limits:
    memory: "2Gi"
    cpu: "1000m"
  requests:
    memory: "1Gi"
    cpu: "500m"

# High Availability
affinity:
  podAntiAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        podAffinityTerm:
          labelSelector:
            matchExpressions:
              - key: app.kubernetes.io/name
                operator: In
                values:
                  - atlantis
          topologyKey: kubernetes.io/hostname

# --- ENHANCEMENT FEATURES ---

# Persistent Storage (EFS for multi-replica)
enhancedStorage:
  enabled: true
  efs:
    storageClass: "efs-sc"
    size: 50Gi

# Prometheus Monitoring
enhancedMonitoring:
  serviceMonitor:
    enabled: true
    interval: "30s"
    labels:
      prometheus: kube-prometheus

# Pod Disruption Budget
enhancedHA:
  podDisruptionBudget:
    enabled: true
    minAvailable: 2
```

Install:

```bash
helm install atlantis k8sforge/atlantis \
  --namespace atlantis \
  --create-namespace \
  -f production-values.yaml
```

### Example 14: AWS EKS Production Setup

Optimized for AWS EKS with IRSA (IAM Roles for Service Accounts).

```yaml
# eks-production-values.yaml
orgAllowlist: "github.com/myorg/*"
replicaCount: 3

githubApp:
  id: "123456"
  slug: "myorg-atlantis"
  key: |
    -----BEGIN RSA PRIVATE KEY-----
    ...
    -----END RSA PRIVATE KEY-----

# Service Account with IRSA annotation
serviceAccount:
  create: true
  annotations:
    eks.amazonaws.com/role-arn: "arn:aws:iam::123456789012:role/atlantis-role"

# ALB Ingress
ingress:
  enabled: true
  ingressClassName: "alb"
  host: "atlantis.example.com"
  annotations:
    alb.ingress.kubernetes.io/scheme: "internet-facing"
    alb.ingress.kubernetes.io/target-type: "ip"
    alb.ingress.kubernetes.io/certificate-arn: "arn:aws:acm:us-east-1:123456789012:certificate/xxx"
    alb.ingress.kubernetes.io/ssl-policy: "ELBSecurityPolicy-TLS-1-2-2017-01"
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}, {"HTTPS":443}]'
    alb.ingress.kubernetes.io/ssl-redirect: "443"

# Resources optimized for EKS
resources:
  limits:
    memory: "4Gi"
    cpu: "2000m"
  requests:
    memory: "2Gi"
    cpu: "1000m"

# Node selector for dedicated node group
nodeSelector:
  workload: "atlantis"

# Tolerations for tainted nodes
tolerations:
  - key: "workload"
    operator: "Equal"
    value: "atlantis"
    effect: "NoSchedule"

# EFS storage for multi-replica
enhancedStorage:
  enabled: true
  efs:
    storageClass: "efs-sc"
    size: 100Gi

# Monitoring and HA
enhancedMonitoring:
  serviceMonitor:
    enabled: true
    interval: "30s"

enhancedHA:
  podDisruptionBudget:
    enabled: true
    minAvailable: 2
```

## Troubleshooting

### Issue: Helm install fails with "dependency not found"

**Solution:**

```bash
# Update dependencies
cd charts/atlantis
helm dependency update
cd ../..

# Try install again
helm install atlantis ./charts/atlantis -f values.yaml
```

### Issue: ServiceMonitor not created

**Error:** ServiceMonitor resource not found in cluster

**Solution:** Install Prometheus Operator

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install prometheus prometheus-community/kube-prometheus-stack

# Verify installation
kubectl get crd servicemonitors.monitoring.coreos.com
```

### Issue: Pod stuck in Pending with PVC

**Error:** `PersistentVolumeClaim is not bound`

**Solution:** Check storage class configuration

```bash
# List available storage classes
kubectl get storageclass

# For EFS (multi-replica), ensure EFS CSI driver is installed
kubectl get deployment efs-csi-controller -n kube-system

# For EBS (single replica), ensure EBS CSI driver is installed
kubectl get deployment ebs-csi-controller -n kube-system
```

### Issue: Values not being passed to official chart

**Symptom:** Configuration changes don't take effect

**Solution:** Ensure values are at root level, not under `atlantis:` key

**Wrong:**

```yaml
atlantis:
  orgAllowlist: "github.com/myorg/*"
```

**Correct:**

```yaml
orgAllowlist: "github.com/myorg/*"
```

### Debug Commands

```bash
# Check what resources are created
helm template atlantis ./charts/atlantis -f values.yaml | grep "kind:"

# Verify values are passed correctly
helm get values atlantis

# Check generated manifest
helm get manifest atlantis

# Check logs
kubectl logs -l app.kubernetes.io/name=atlantis

# Port-forward for local testing
kubectl port-forward svc/atlantis 4141:4141
```

## Additional Resources

- [Official Atlantis Documentation](https://www.runatlantis.io/)
- [Official Chart Values Reference](https://github.com/runatlantis/helm-charts/tree/main/charts/atlantis)
- [Chart Repository](https://github.com/k8sforge/atlantis-chart)
