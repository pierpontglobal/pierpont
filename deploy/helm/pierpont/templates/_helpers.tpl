{{- define "pierpont.labels" -}}
app.kubernetes.io/part-of: pierpont
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}
{{- define "pierpont.pullSecrets" -}}
{{- with .Values.imagePullSecrets }}
imagePullSecrets:
{{- range . }}
  - name: {{ . }}
{{- end }}
{{- end }}
{{- end }}
