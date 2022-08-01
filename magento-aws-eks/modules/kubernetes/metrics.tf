# Monitoring: Metric Server - Prometheus - Grafana

resource "helm_release" "metrics_server" {

  name            = "metrics-server"
  repository      = "https://kubernetes-sigs.github.io/metrics-server/"
  chart           = "metrics-server"
  namespace       = kubernetes_namespace_v1.monitoring-namespace.id
  cleanup_on_fail = true
  force_update    = false

}
