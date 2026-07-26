{{- define "healthcare-platform.name" -}}
{{- .Chart.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "healthcare-platform.fullname" -}}
{{- printf "%s-%s" .Release.Name (include "healthcare-platform.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "healthcare-platform.labels" -}}
app.kubernetes.io/name: {{ include "healthcare-platform.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version | replace "+" "_" }}
{{- end -}}

{{- define "healthcare-platform.selectorLabels" -}}
app.kubernetes.io/name: {{ include "healthcare-platform.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}
