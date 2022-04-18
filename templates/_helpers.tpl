{{/*
Expand the name of the chart.
*/}}
{{- define "httpbin.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}
{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "httpbin.fullname" -}}
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
{{- define "httpbin.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}
{{/*
Common labels
*/}}
{{- define "httpbin.labels" -}}
{{ include "httpbin.selectorLabels" . }}
service: {{default (include "httpbin.fullname" .) }}
{{- end }}
{{/*
Selector labels
*/}}
{{- define "httpbin.selectorLabels" -}}
app: {{default (include "httpbin.fullname" .) }}
{{- end }}
{{/*
Selector version
*/}}
{{- define "httpbin.selectorVersion" -}}
version: {{ .Values.version }}
{{- end }}

{{/*
Selector istio
*/}}
{{- define "httpbin.selectorIstio" -}}
{{- printf "istio: %s"  (default "ingressgateway" .Values.gateway.selector.istio) }}
{{- end }}

{{/*
Hosts gateway
*/}}
{{- define "httpbin.gatewayHosts" -}}
{{- default "*" .Values.gateway.hosts | quote}}
{{- end }}

{{/*
Port gateway
*/}}
{{- define "httpbin.gatewayPortNumber" -}}
{{- default .Values.gateway.port.number 80 }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "httpbin.selectorLabelsWithVersion" -}}
{{ include "httpbin.selectorLabels" . }}
{{ include "httpbin.selectorVersion" . }}
{{- end }}


{{/*
Create the name of the service account to use
*/}}
{{- define "httpbin.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "httpbin.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Create the name of the gateway name to use
*/}}
{{- define "httpbin.gatewayName" -}}
{{- if .Values.gateway.name }}
{{- .Values.gateway.name }}
{{- else }}
{{- printf "%s-%s"  (include "httpbin.fullname" . | trunc 61 )  "gw" }}
{{- end }}
{{- end }}

{{/*
Create the name of the virtual service name to use
*/}}
{{- define "httpbin.virtualServiceName" -}}
{{- if .Values.vitualService.name }}
{{- .Values.vitualService.name }}
{{- else }}
{{- printf "%s-%s"  (include "httpbin.fullname" . | trunc 61 )  "vs" }}
{{- end }}
{{- end }}

{{/*
Service Name
*/}}
{{- define "httpbin.serviceName" -}}
{{- if .Values.service.name }}
{{- .Values.service.name }}
{{- else }}
{{- printf "%s-%s"  (include "httpbin.fullname" . | trunc 60 )  "svc" }}
{{- end }}
{{- end }}

{{/*
Route Name
*/}}
{{- define "httpbin.routeName" -}}
{{- if .Values.route.name }}
{{- .Values.route.name }}
{{- else }}
{{- printf "%s-%s"  (include "httpbin.fullname" . | trunc 60 )  "route" }}
{{- end }}
{{- end }}