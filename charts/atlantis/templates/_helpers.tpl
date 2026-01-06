{{/*
Expand the name of the chart.
*/}}
{{- define "atlantis.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "atlantis.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "atlantis.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "atlantis.labels" -}}
helm.sh/chart: {{ include "atlantis.chart" . }}
{{ include "atlantis.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- with .Values.labels }}
{{- toYaml . | nindent 0 }}
{{- end }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "atlantis.selectorLabels" -}}
app.kubernetes.io/name: {{ include "atlantis.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "atlantis.serviceAccountName" -}}
{{- if .Values.atlantisConfig.serviceAccount.create }}
{{- default (include "atlantis.fullname" .) .Values.atlantisConfig.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.atlantisConfig.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Enhanced pod template for Argo Rollouts (uses official chart's pod spec as base)
This template is used by our Rollout resource when deployment.type == "rollout"
The official chart handles the standard Deployment pod template
*/}}
{{- define "atlantis.rolloutPodTemplate" -}}
metadata:
  labels:
    {{- include "atlantis.selectorLabels" . | nindent 4 }}
    {{- with .Values.atlantisConfig.podLabels }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
  {{- with .Values.atlantisConfig.podAnnotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  {{- with .Values.atlantisConfig.imagePullSecrets }}
  imagePullSecrets:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  serviceAccountName: {{ include "atlantis.serviceAccountName" . }}
  securityContext:
    {{- toYaml .Values.atlantisConfig.podSecurityContext | nindent 4 }}
  {{- with .Values.atlantisConfig.nodeSelector }}
  nodeSelector:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with .Values.atlantisConfig.affinity }}
  affinity:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with .Values.atlantisConfig.tolerations }}
  tolerations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  containers:
    - name: atlantis
      securityContext:
        {{- toYaml .Values.atlantisConfig.securityContext | nindent 8 }}
      image: "{{ .Values.atlantisConfig.image.repository }}:{{ .Values.atlantisConfig.image.tag | default .Chart.AppVersion }}"
      imagePullPolicy: {{ .Values.atlantisConfig.image.pullPolicy }}
      ports:
        - containerPort: {{ .Values.atlantisConfig.service.port }}
          name: http
      env:
        - name: ATLANTIS_DATA_DIR
          value: "/atlantis-data"
        - name: ATLANTIS_REPO_ALLOWLIST
          valueFrom:
            configMapKeyRef:
              name: {{ include "atlantis.fullname" . }}-config
              key: repo-allowlist
        {{- if .Values.atlantisConfig.atlantisUrl }}
        - name: ATLANTIS_ATLANTIS_URL
          valueFrom:
            configMapKeyRef:
              name: {{ include "atlantis.fullname" . }}-config
              key: atlantis-url
        {{- end }}
        - name: ATLANTIS_LOG_LEVEL
          valueFrom:
            configMapKeyRef:
              name: {{ include "atlantis.fullname" . }}-config
              key: log-level
        {{- if .Values.atlantisConfig.github.user }}
        - name: ATLANTIS_GH_USER
          valueFrom:
            secretKeyRef:
              name: {{ include "atlantis.fullname" . }}-secrets
              key: github-user
        {{- end }}
        {{- if .Values.atlantisConfig.github.token }}
        - name: ATLANTIS_GH_TOKEN
          valueFrom:
            secretKeyRef:
              name: {{ include "atlantis.fullname" . }}-secrets
              key: github-token
        {{- end }}
        {{- if .Values.atlantisConfig.github.secret }}
        - name: ATLANTIS_GH_WEBHOOK_SECRET
          valueFrom:
            secretKeyRef:
              name: {{ include "atlantis.fullname" . }}-secrets
              key: webhook-secret
        {{- end }}
        {{- if .Values.atlantisConfig.githubApp.id }}
        - name: ATLANTIS_GH_APP_ID
          valueFrom:
            secretKeyRef:
              name: {{ include "atlantis.fullname" . }}-secrets
              key: github-app-id
        - name: ATLANTIS_GH_APP_KEY_FILE
          value: "/atlantis-data/github-app-key.pem"
        {{- end }}
        {{- if .Values.atlantisConfig.githubApp.installationId }}
        - name: ATLANTIS_GH_APP_INSTALLATION_ID
          valueFrom:
            secretKeyRef:
              name: {{ include "atlantis.fullname" . }}-secrets
              key: github-app-installation-id
        {{- end }}
        {{- range $key, $value := .Values.atlantisConfig.environment }}
        - name: {{ $key }}
          value: {{ $value | quote }}
        {{- end }}
        {{- range .Values.atlantisConfig.environmentSecrets }}
        - name: {{ .name }}
          valueFrom:
            secretKeyRef:
              name: {{ .secretName }}
              key: {{ .secretKey }}
        {{- end }}
      resources:
        {{- toYaml .Values.atlantisConfig.resources | nindent 8 }}
      {{- if .Values.atlantisConfig.livenessProbe.enabled }}
      livenessProbe:
        httpGet:
          path: {{ .Values.atlantisConfig.livenessProbe.path }}
          port: http
          scheme: {{ .Values.atlantisConfig.livenessProbe.scheme }}
        initialDelaySeconds: {{ .Values.atlantisConfig.livenessProbe.initialDelaySeconds }}
        periodSeconds: {{ .Values.atlantisConfig.livenessProbe.periodSeconds }}
        timeoutSeconds: {{ .Values.atlantisConfig.livenessProbe.timeoutSeconds }}
        successThreshold: {{ .Values.atlantisConfig.livenessProbe.successThreshold }}
        failureThreshold: {{ .Values.atlantisConfig.livenessProbe.failureThreshold }}
      {{- end }}
      {{- if .Values.atlantisConfig.readinessProbe.enabled }}
      readinessProbe:
        httpGet:
          path: {{ .Values.atlantisConfig.readinessProbe.path }}
          port: http
          scheme: {{ .Values.atlantisConfig.readinessProbe.scheme }}
        initialDelaySeconds: {{ .Values.atlantisConfig.readinessProbe.initialDelaySeconds }}
        periodSeconds: {{ .Values.atlantisConfig.readinessProbe.periodSeconds }}
        timeoutSeconds: {{ .Values.atlantisConfig.readinessProbe.timeoutSeconds }}
        successThreshold: {{ .Values.atlantisConfig.readinessProbe.successThreshold }}
        failureThreshold: {{ .Values.atlantisConfig.readinessProbe.failureThreshold }}
      {{- end }}
      volumeMounts:
        - name: atlantis-data
          mountPath: /atlantis-data
        {{- if .Values.atlantisConfig.githubApp.key }}
        - name: github-app-key
          mountPath: /atlantis-data/github-app-key.pem
          subPath: github-app-key.pem
          readOnly: true
        {{- end }}
        {{- range .Values.atlantisConfig.extraVolumeMounts }}
        - name: {{ .name }}
          mountPath: {{ .mountPath }}
          {{- if .subPath }}
          subPath: {{ .subPath }}
          {{- end }}
          {{- if .readOnly }}
          readOnly: {{ .readOnly }}
          {{- end }}
        {{- end }}
  volumes:
    - name: atlantis-data
      {{- if .Values.persistence.enabled }}
      {{- if .Values.persistence.existingClaim }}
      persistentVolumeClaim:
        claimName: {{ .Values.persistence.existingClaim | quote }}
      {{- else }}
      persistentVolumeClaim:
        claimName: {{ include "atlantis.fullname" . }}-data
      {{- end }}
      {{- else }}
      emptyDir: {}
      {{- end }}
    {{- if .Values.atlantisConfig.githubApp.key }}
    - name: github-app-key
      secret:
        secretName: {{ include "atlantis.fullname" . }}-secrets
        items:
          - key: github-app-key
            path: github-app-key.pem
    {{- end }}
    {{- range .Values.atlantisConfig.extraVolumes }}
    - name: {{ .name }}
      {{- if .configMap }}
      configMap:
        name: {{ .configMap.name }}
        {{- if .configMap.items }}
        items:
          {{- range .configMap.items }}
          - key: {{ .key }}
            path: {{ .path }}
          {{- end }}
        {{- end }}
      {{- else if .secret }}
      secret:
        secretName: {{ .secret.secretName }}
        {{- if .secret.items }}
        items:
          {{- range .secret.items }}
          - key: {{ .key }}
            path: {{ .path }}
          {{- end }}
        {{- end }}
      {{- else if .emptyDir }}
      emptyDir: {}
      {{- end }}
    {{- end }}
{{- end }}

{{/*
Validate persistence configuration based on replica count
Ensures proper storage selection and prevents deployment failures
Uses replica count from chart configuration
*/}}
{{- define "atlantis.validatePersistence" -}}
{{- if .Values.persistence.enabled }}
{{- $replicaCount := .Values.replicaCount | int }}
{{- $storageClass := "" }}
{{- if .Values.persistence.storageClass }}
  {{- $storageClass = .Values.persistence.storageClass }}
{{- else }}
  {{- if eq $replicaCount 1 }}
    {{- $storageClass = .Values.persistence.ebs.storageClass }}
  {{- else }}
    {{- $storageClass = .Values.persistence.efs.storageClass }}
  {{- end }}
{{- end }}

{{- if and (gt $replicaCount 1) (not $storageClass) }}
{{- fail "ERROR: Multi-replica deployment (replicaCount > 1) with persistence requires a storage class for EFS. Please set persistence.efs.storageClass or use persistence.storageClass override." }}
{{- end }}

{{- if and (eq $replicaCount 1) (not $storageClass) }}
{{- fail "ERROR: Single replica deployment with persistence requires a storage class for EBS. Please set persistence.ebs.storageClass or use persistence.storageClass override." }}
{{- end }}

{{- $accessMode := "" }}
{{- if .Values.persistence.accessModes }}
  {{- range .Values.persistence.accessModes }}
    {{- $accessMode = . }}
  {{- end }}
{{- else }}
  {{- if eq $replicaCount 1 }}
    {{- $accessMode = "ReadWriteOnce" }}
  {{- else }}
    {{- $accessMode = "ReadWriteMany" }}
  {{- end }}
{{- end }}

{{- if and (gt $replicaCount 1) (ne $accessMode "ReadWriteMany") }}
{{- fail "ERROR: Multi-replica deployment (replicaCount > 1) with persistence requires ReadWriteMany access mode. Either set replicaCount=1, disable persistence, use persistence.accessModes=[\"ReadWriteMany\"], or configure EFS storage." }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Conditional replica count for official chart
When using Rollouts, disable the official chart's deployment by setting replicas to 0
*/}}
{{- define "atlantis.officialChartReplicaCount" -}}
{{- if eq .Values.deployment.type "rollout" }}
0
{{- else }}
{{ .Values.atlantisConfig.replicaCount }}
{{- end }}
{{- end }}

{{/*
Value transformation helper for official chart compatibility
Filters and transforms atlantisConfig: values to be compatible with the official chart schema
*/}}
{{- define "atlantis.officialChartValues" -}}
# Core configuration - pass as-is
{{- if .Values.atlantisConfig.orgAllowlist }}
orgAllowlist: {{ .Values.atlantisConfig.orgAllowlist | quote }}
{{- end }}
{{- if .Values.atlantisConfig.atlantisUrl }}
atlantisUrl: {{ .Values.atlantisConfig.atlantisUrl | quote }}
{{- end }}
{{- if .Values.atlantisConfig.logLevel }}
logLevel: {{ .Values.atlantisConfig.logLevel | quote }}
{{- end }}

# Authentication - pass as-is
{{- if .Values.atlantisConfig.github }}
github:
{{- toYaml .Values.atlantisConfig.github | nindent 2 }}
{{- end }}
{{- if .Values.atlantisConfig.githubApp }}
githubApp:
{{- toYaml .Values.atlantisConfig.githubApp | nindent 2 }}
{{- end }}

# Image configuration - pass as-is
{{- if .Values.atlantisConfig.image }}
image:
{{- toYaml .Values.atlantisConfig.image | nindent 2 }}
{{- end }}
{{- if .Values.atlantisConfig.imagePullSecrets }}
imagePullSecrets:
{{- toYaml .Values.atlantisConfig.imagePullSecrets | nindent 2 }}
{{- end }}

# Replica count - use conditional value
replicaCount: {{ include "atlantis.officialChartReplicaCount" . }}

# Service configuration - pass as-is
{{- if .Values.atlantisConfig.service }}
service:
{{- toYaml .Values.atlantisConfig.service | nindent 2 }}
{{- end }}

# Ingress configuration - pass as-is
{{- if .Values.atlantisConfig.ingress }}
ingress:
{{- toYaml .Values.atlantisConfig.ingress | nindent 2 }}
{{- end }}

# Resources - pass as-is
{{- if .Values.atlantisConfig.resources }}
resources:
{{- toYaml .Values.atlantisConfig.resources | nindent 2 }}
{{- end }}

# Node scheduling - pass as-is
{{- if .Values.atlantisConfig.nodeSelector }}
nodeSelector:
{{- toYaml .Values.atlantisConfig.nodeSelector | nindent 2 }}
{{- end }}
{{- if .Values.atlantisConfig.tolerations }}
tolerations:
{{- toYaml .Values.atlantisConfig.tolerations | nindent 2 }}
{{- end }}
{{- if .Values.atlantisConfig.affinity }}
affinity:
{{- toYaml .Values.atlantisConfig.affinity | nindent 2 }}
{{- end }}

# Service account - pass as-is
{{- if .Values.atlantisConfig.serviceAccount }}
serviceAccount:
{{- toYaml .Values.atlantisConfig.serviceAccount | nindent 2 }}
{{- end }}

# Environment - pass as-is
{{- if .Values.atlantisConfig.environment }}
environment:
{{- toYaml .Values.atlantisConfig.environment | nindent 2 }}
{{- end }}
{{- if .Values.atlantisConfig.environmentSecrets }}
environmentSecrets:
{{- toYaml .Values.atlantisConfig.environmentSecrets | nindent 2 }}
{{- end }}

# Container command - pass as-is
{{- if .Values.atlantisConfig.command }}
command:
{{- toYaml .Values.atlantisConfig.command | nindent 2 }}
{{- end }}

# TRANSFORM: dataStorage object → string for official chart compatibility
# CRITICAL: Official chart expects dataStorage as a STRING, not object
{{- $dataStorageValue := "" }}
{{- if .Values.atlantisConfig.dataStorage }}
  {{- if and .Values.atlantisConfig.dataStorage.enabled .Values.atlantisConfig.dataStorage.size }}
    {{- $dataStorageValue = .Values.atlantisConfig.dataStorage.size }}
  {{- end }}
{{- end }}
dataStorage: {{ $dataStorageValue | quote }}

# Probes - filter out enhanced properties, keep only official chart compatible ones
{{- if .Values.atlantisConfig.livenessProbe }}
livenessProbe:
  enabled: {{ .Values.atlantisConfig.livenessProbe.enabled }}
  periodSeconds: {{ .Values.atlantisConfig.livenessProbe.periodSeconds }}
  initialDelaySeconds: {{ .Values.atlantisConfig.livenessProbe.initialDelaySeconds }}
  timeoutSeconds: {{ .Values.atlantisConfig.livenessProbe.timeoutSeconds }}
  successThreshold: {{ .Values.atlantisConfig.livenessProbe.successThreshold }}
  failureThreshold: {{ .Values.atlantisConfig.livenessProbe.failureThreshold }}
{{- end }}
{{- if .Values.atlantisConfig.readinessProbe }}
readinessProbe:
  enabled: {{ .Values.atlantisConfig.readinessProbe.enabled }}
  periodSeconds: {{ .Values.atlantisConfig.readinessProbe.periodSeconds }}
  initialDelaySeconds: {{ .Values.atlantisConfig.readinessProbe.initialDelaySeconds }}
  timeoutSeconds: {{ .Values.atlantisConfig.readinessProbe.timeoutSeconds }}
  successThreshold: {{ .Values.atlantisConfig.readinessProbe.successThreshold }}
  failureThreshold: {{ .Values.atlantisConfig.readinessProbe.failureThreshold }}
{{- end }}

# Volume configuration - only pass supported properties
{{- if .Values.atlantisConfig.extraVolumes }}
extraVolumes:
{{- toYaml .Values.atlantisConfig.extraVolumes | nindent 2 }}
{{- end }}
{{- if .Values.atlantisConfig.extraVolumeMounts }}
extraVolumeMounts:
{{- toYaml .Values.atlantisConfig.extraVolumeMounts | nindent 2 }}
{{- end }}

# Container configuration - only pass supported properties
{{- if .Values.atlantisConfig.initContainers }}
initContainers:
{{- toYaml .Values.atlantisConfig.initContainers | nindent 2 }}
{{- end }}
{{- if .Values.atlantisConfig.extraContainers }}
extraContainers:
{{- toYaml .Values.atlantisConfig.extraContainers | nindent 2 }}
{{- end }}

# EXCLUDED PROPERTIES (not supported by official chart):
# - volumeClaim: Array format not compatible with official chart
# - statefulSet: Not supported by official Atlantis chart
# - disruptionBudget: Wrapper provides enhanced PDB instead

# EXCLUDE: These properties are used only by wrapper templates
# - podLabels (not supported by official chart)
# - podAnnotations (not supported by official chart)
# - podSecurityContext (not supported by official chart)
# - securityContext (not supported by official chart)
# - scheme/path properties in probes (not supported by official chart)
{{- end }}

{{/*
Validation helper for subchart compatibility
Warns users about incompatible value combinations when using official chart deployment
*/}}
{{- define "atlantis.validateSubchartCompatibility" -}}
{{- if eq .Values.deployment.type "deployment" }}
{{- if .Values.atlantisConfig.podLabels }}
{{- fail "ERROR: podLabels are not supported by the official Atlantis chart when deployment.type='deployment'. Use deployment.type='rollout' for enhanced pod label support, or remove podLabels configuration." }}
{{- end }}
{{- if .Values.atlantisConfig.podAnnotations }}
{{- fail "ERROR: podAnnotations are not supported by the official Atlantis chart when deployment.type='deployment'. Use deployment.type='rollout' for enhanced pod annotation support, or remove podAnnotations configuration." }}
{{- end }}
{{- if .Values.atlantisConfig.podSecurityContext }}
{{- fail "ERROR: podSecurityContext is not supported by the official Atlantis chart when deployment.type='deployment'. Use deployment.type='rollout' for enhanced security context support, or remove podSecurityContext configuration." }}
{{- end }}
{{- if .Values.atlantisConfig.securityContext }}
{{- fail "ERROR: securityContext is not supported by the official Atlantis chart when deployment.type='deployment'. Use deployment.type='rollout' for enhanced security context support, or remove securityContext configuration." }}
{{- end }}
{{- if and .Values.atlantisConfig.livenessProbe.enabled (or .Values.atlantisConfig.livenessProbe.path .Values.atlantisConfig.livenessProbe.scheme) }}
{{- fail "ERROR: livenessProbe 'path' and 'scheme' properties are not supported by the official Atlantis chart when deployment.type='deployment'. Use deployment.type='rollout' for enhanced probe support, or use only basic probe properties (enabled, periodSeconds, etc.)." }}
{{- end }}
{{- if and .Values.atlantisConfig.readinessProbe.enabled (or .Values.atlantisConfig.readinessProbe.path .Values.atlantisConfig.readinessProbe.scheme) }}
{{- fail "ERROR: readinessProbe 'path' and 'scheme' properties are not supported by the official Atlantis chart when deployment.type='deployment'. Use deployment.type='rollout' for enhanced probe support, or use only basic probe properties (enabled, periodSeconds, etc.)." }}
{{- end }}
{{- if and .Values.atlantisConfig.dataStorage (ne .Values.atlantisConfig.dataStorage.enabled false) (not .Values.atlantisConfig.dataStorage.size) }}
{{- fail "ERROR: When dataStorage.enabled=true, dataStorage.size must be specified for compatibility with the official Atlantis chart." }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Validation helper for deployment type configuration
Ensures deployment type is properly configured with required dependencies
*/}}
{{- define "atlantis.validateDeploymentType" -}}
{{- if eq .Values.deployment.type "rollout" }}
{{- if not .Values.replicaCount }}
{{- fail "ERROR: replicaCount must be specified when deployment.type='rollout'." }}
{{- end }}
{{- if lt (.Values.replicaCount | int) 1 }}
{{- fail "ERROR: replicaCount must be at least 1 when deployment.type='rollout'." }}
{{- end }}
{{- end }}
{{- if and (eq .Values.deployment.type "rollout") (eq .Values.deployment.strategy "blueGreen") }}
{{- if not (eq .Values.replicaCount 1) }}
{{- fail "WARNING: Blue-Green deployments work best with replicaCount=1 for clean traffic switching. Current replicaCount={{ .Values.replicaCount }}." }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Validation helper for enhanced storage configuration
Validates persistence configuration for compatibility
*/}}
{{- define "atlantis.validateEnhancedStorage" -}}
{{- if .Values.persistence.enabled }}
{{- $replicaCount := 1 }}
{{- if eq .Values.deployment.type "rollout" }}
{{- $replicaCount = .Values.replicaCount }}
{{- else }}
{{- $replicaCount = .Values.atlantisConfig.replicaCount }}
{{- end }}
{{- if and (gt ($replicaCount | int) 1) (not .Values.persistence.efs.storageClass) (not .Values.persistence.storageClass) }}
{{- fail "ERROR: Multi-replica deployment (replicaCount > 1) with persistence requires EFS storage. Set persistence.efs.storageClass or persistence.storageClass for ReadWriteMany support." }}
{{- end }}
{{- if and (eq ($replicaCount | int) 1) (not .Values.persistence.ebs.storageClass) (not .Values.persistence.storageClass) }}
{{- fail "ERROR: Single replica deployment with persistence requires EBS storage. Set persistence.ebs.storageClass or persistence.storageClass." }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Validation helper for transformation output
Ensures that subchart values are properly formatted and compatible
*/}}
{{- define "atlantis.validateTransformation" -}}
{{/* Validate dataStorage is always a string */}}
{{- if .Values.atlantis.dataStorage }}
  {{- if not (kindIs "string" .Values.atlantis.dataStorage) }}
    {{- fail "ERROR: atlantis.dataStorage must be a string value for official chart compatibility. Current type is not string." }}
  {{- end }}
{{- end }}

{{/* Validate no double-nesting in atlantis section */}}
{{- if .Values.atlantis.atlantis }}
  {{- fail "ERROR: Double-nesting detected (atlantis.atlantis.*). Check value transformation logic for nested atlantis keys." }}
{{- end }}

{{/* Validate unsupported properties are not present */}}
{{- if .Values.atlantis.podLabels }}
  {{- fail "ERROR: atlantis.podLabels should not be passed to official chart. Use atlantisConfig.podLabels instead." }}
{{- end }}
{{- if .Values.atlantis.podAnnotations }}
  {{- fail "ERROR: atlantis.podAnnotations should not be passed to official chart. Use atlantisConfig.podAnnotations instead." }}
{{- end }}
{{- if .Values.atlantis.podSecurityContext }}
  {{- fail "ERROR: atlantis.podSecurityContext should not be passed to official chart. Use atlantisConfig.podSecurityContext instead." }}
{{- end }}
{{- if .Values.atlantis.securityContext }}
  {{- fail "ERROR: atlantis.securityContext should not be passed to official chart. Use atlantisConfig.securityContext instead." }}
{{- end }}
{{- if .Values.atlantis.statefulSet }}
  {{- fail "ERROR: atlantis.statefulSet should not be passed to official chart. Property not supported by official chart." }}
{{- end }}

{{/* Validate environment variables are properly typed */}}
{{- if .Values.atlantis.environment }}
  {{- if not (kindIs "map" .Values.atlantis.environment) }}
    {{- fail "ERROR: atlantis.environment must be a map/object of key-value pairs." }}
  {{- end }}
  {{- range $key, $value := .Values.atlantis.environment }}
    {{- if not (kindIs "string" $value) }}
      {{- fail (printf "ERROR: atlantis.environment.%s must be a string value. Current value: %v" $key $value) }}
    {{- end }}
  {{- end }}
{{- end }}

{{/* Validate replica count is an integer */}}
{{- if .Values.atlantis.replicaCount }}
  {{- if not (kindIs "float64" .Values.atlantis.replicaCount) }}
    {{- fail "ERROR: atlantis.replicaCount must be an integer value." }}
  {{- end }}
  {{- if lt (.Values.atlantis.replicaCount | int) 0 }}
    {{- fail "ERROR: atlantis.replicaCount must be non-negative." }}
  {{- end }}
{{- end }}

{{/* Validate service port is an integer */}}
{{- if and .Values.atlantis.service .Values.atlantis.service.port }}
  {{- if not (kindIs "float64" .Values.atlantis.service.port) }}
    {{- fail "ERROR: atlantis.service.port must be an integer value." }}
  {{- end }}
{{- end }}
{{- end }}

{{/*
Validation helper for overall chart configuration
Runs all validations to ensure proper configuration
*/}}
{{- define "atlantis.validateAll" -}}
{{- include "atlantis.validateSubchartCompatibility" . }}
{{- include "atlantis.validateDeploymentType" . }}
{{- include "atlantis.validateEnhancedStorage" . }}
{{- include "atlantis.validateTransformation" . }}
{{- end }}

