{{/* Standardized App Name Clamps */}}
{{- define "multi-tenant-app.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/* Standardized Release Component Clamps */}}
{{- define "multi-tenant-app.fullname" -}}
{{- printf "%s-%s" .Release.Name .Chart.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/* Enterprise Compliance Labels for Metadata Tracking */}}
{{- define "multi-tenant-app.labels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/instance: {{ .Release.Name }}
enterprise.security/compliance-tier: "pci-dss-hardened"
enterprise.security/tenant-isolation: "logical-mesh"
{{- end -}}

{{/* Selector Labels for Service Resolution Mesh */}}
{{- define "multi-tenant-app.selectorLabels" -}}
app.kubernetes.io/name: {{ include "multi-tenant-app.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}