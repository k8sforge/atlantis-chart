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
{{- if .Values.serviceAccount.create }}
{{- default (include "atlantis.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
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
  {{- with .Values.podAnnotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  {{- with .Values.imagePullSecrets }}
  imagePullSecrets:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  serviceAccountName: {{ include "atlantis.serviceAccountName" . }}
  securityContext:
    {{- toYaml .Values.podSecurityContext | nindent 4 }}
  {{- with .Values.nodeSelector }}
  nodeSelector:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with .Values.affinity }}
  affinity:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with .Values.tolerations }}
  tolerations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  containers:
    - name: atlantis
      securityContext:
        {{- toYaml .Values.securityContext | nindent 8 }}
      image: "{{ .Values.image.repository }}:{{ .Values.image.tag | default .Chart.AppVersion }}"
      imagePullPolicy: {{ .Values.image.pullPolicy }}
      ports:
        - containerPort: {{ .Values.service.port }}
          name: http
      env:
        - name: ATLANTIS_DATA_DIR
          value: "/atlantis-data"
        - name: ATLANTIS_REPO_ALLOWLIST
          valueFrom:
            configMapKeyRef:
              name: {{ include "atlantis.fullname" . }}-config
              key: repo-allowlist
        {{- if .Values.atlantisUrl }}
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
        {{- if .Values.github.user }}
        - name: ATLANTIS_GH_USER
          valueFrom:
            secretKeyRef:
              name: {{ include "atlantis.fullname" . }}-secrets
              key: github-user
        {{- end }}
        {{- if .Values.github.token }}
        - name: ATLANTIS_GH_TOKEN
          valueFrom:
            secretKeyRef:
              name: {{ include "atlantis.fullname" . }}-secrets
              key: github-token
        {{- end }}
        {{- if .Values.github.secret }}
        - name: ATLANTIS_GH_WEBHOOK_SECRET
          valueFrom:
            secretKeyRef:
              name: {{ include "atlantis.fullname" . }}-secrets
              key: webhook-secret
        {{- end }}
        {{- if .Values.githubApp.id }}
        - name: ATLANTIS_GH_APP_ID
          valueFrom:
            secretKeyRef:
              name: {{ include "atlantis.fullname" . }}-secrets
              key: github-app-id
        - name: ATLANTIS_GH_APP_KEY_FILE
          value: "/atlantis-data/github-app-key.pem"
        {{- end }}
        {{- if .Values.githubApp.installationId }}
        - name: ATLANTIS_GH_APP_INSTALLATION_ID
          valueFrom:
            secretKeyRef:
              name: {{ include "atlantis.fullname" . }}-secrets
              key: github-app-installation-id
        {{- end }}
        {{- range $key, $value := .Values.environment }}
        - name: {{ $key }}
          value: {{ $value | quote }}
        {{- end }}
        {{- range .Values.environmentSecrets }}
        - name: {{ .name }}
          valueFrom:
            secretKeyRef:
              name: {{ .secretName }}
              key: {{ .secretKey }}
        {{- end }}
      resources:
        {{- toYaml .Values.resources | nindent 8 }}
      {{- if .Values.livenessProbe.enabled }}
      livenessProbe:
        httpGet:
          path: {{ .Values.livenessProbe.path }}
          port: http
          scheme: {{ .Values.livenessProbe.scheme }}
        initialDelaySeconds: {{ .Values.livenessProbe.initialDelaySeconds }}
        periodSeconds: {{ .Values.livenessProbe.periodSeconds }}
        timeoutSeconds: {{ .Values.livenessProbe.timeoutSeconds }}
        successThreshold: {{ .Values.livenessProbe.successThreshold }}
        failureThreshold: {{ .Values.livenessProbe.failureThreshold }}
      {{- end }}
      {{- if .Values.readinessProbe.enabled }}
      readinessProbe:
        httpGet:
          path: {{ .Values.readinessProbe.path }}
          port: http
          scheme: {{ .Values.readinessProbe.scheme }}
        initialDelaySeconds: {{ .Values.readinessProbe.initialDelaySeconds }}
        periodSeconds: {{ .Values.readinessProbe.periodSeconds }}
        timeoutSeconds: {{ .Values.readinessProbe.timeoutSeconds }}
        successThreshold: {{ .Values.readinessProbe.successThreshold }}
        failureThreshold: {{ .Values.readinessProbe.failureThreshold }}
      {{- end }}
      volumeMounts:
        - name: atlantis-data
          mountPath: /atlantis-data
        {{- if .Values.githubApp.key }}
        - name: github-app-key
          mountPath: /atlantis-data/github-app-key.pem
          subPath: github-app-key.pem
          readOnly: true
        {{- end }}
        {{- range .Values.extraVolumeMounts }}
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
    {{- if .Values.githubApp.key }}
    - name: github-app-key
      secret:
        secretName: {{ include "atlantis.fullname" . }}-secrets
        items:
          - key: github-app-key
            path: github-app-key.pem
    {{- end }}
    {{- range .Values.extraVolumes }}
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

