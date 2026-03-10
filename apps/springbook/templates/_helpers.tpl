{{/*
Expand the name of the chart.
*/}}
{{- define "springbook.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "springbook.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- .Chart.Name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}

{{/*
Namespace (prefer .Release.Namespace; fallback to values)
*/}}
{{- define "springbook.namespace" -}}
{{- default .Release.Namespace .Values.namespace | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Backend JDBC URL (mysql-svc/bookdb)
*/}}
{{- define "springbook.backend.jdbcUrl" -}}
jdbc:mysql://{{ .Values.mysql.service.name }}/{{ .Values.mysql.auth.database }}
{{- end }}
