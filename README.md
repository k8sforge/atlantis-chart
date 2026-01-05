# Atlantis Helm Chart Repository

![Auto Tag Release](https://github.com/k8sforge/atlantis-chart/actions/workflows/chart-releaser.yml/badge.svg)

This is a Helm chart repository for the [Atlantis](https://www.runatlantis.io/) Helm chart.

## Quick Start

### Add the Repository

```bash
helm repo add atlantis https://k8sforge.github.io/atlantis-chart
helm repo update
```

### Install the Chart

```bash
helm install my-atlantis atlantis/atlantis --version <version>
```

### List Available Versions

```bash
helm search repo atlantis/atlantis --versions
```

## Chart Information

- **Chart Name**: `atlantis`
- **Repository**: `https://k8sforge.github.io/atlantis-chart`
- **Latest Version**: See [index.yaml](index.yaml) for available versions

## Documentation

For complete documentation, configuration options, and examples, visit the [main repository](https://github.com/k8sforge/atlantis-chart).

## Alternative: OCI Installation

This chart is also available via OCI registry:

```bash
helm install my-atlantis \
  oci://ghcr.io/k8sforge/atlantis-chart/atlantis \
  --version <version>
```

## Support

- **Issues**: [GitHub Issues](https://github.com/k8sforge/atlantis-chart/issues)
- **Source Code**: [GitHub Repository](https://github.com/k8sforge/atlantis-chart)
