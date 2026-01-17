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
Since we're a wrapper, we reference the service account created by the official chart
*/}}
{{- define "atlantis.serviceAccountName" -}}
{{- include "atlantis.fullname" . }}
{{- end }}

{{/*
Generate environmentSecrets configuration for atlantis when githubAppSecrets is enabled
*/}}
{{- define "atlantis.githubAppSecrets.envSecrets" -}}
{{- if .Values.githubAppSecrets.enabled }}
- name: {{ .Values.githubAppSecrets.secretName }}
  keys:
    - {{ .Values.githubAppSecrets.keys.appId | default "value" }}
    - {{ .Values.githubAppSecrets.keys.appKey | default "value" }}
    - {{ .Values.githubAppSecrets.keys.webhookSecret | default "value" }}
{{- end }}
{{- end }}

{{/*
Generate environment variable mappings for GitHub App credentials
*/}}
{{- define "atlantis.githubAppSecrets.env" -}}
{{- if .Values.githubAppSecrets.enabled }}
{{- $keys := .Values.githubAppSecrets.keys }}
ATLANTIS_GH_APP_ID: ${{ $keys.appId | default "value" }}
ATLANTIS_GH_APP_KEY: ${{ $keys.appKey | default "value" }}
ATLANTIS_GH_WEBHOOK_SECRET: ${{ $keys.webhookSecret | default "value" }}
{{- end }}
{{- end }}
