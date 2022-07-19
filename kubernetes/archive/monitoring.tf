
resource "helm_release" "prometheus" {

  name       = "prometheus"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "prometheus"
  namespace  = kubernetes_namespace_v1.monitoring-namespace.id

  depends_on = [ helm_release.metrics_server ]

  set {
    name  = "alertmanager.persistentVolume.storageClass"
    value = "gp2"
  }

  set {
    name  = "server.persistentVolume.storageClass"
    value = "gp2"
  }  

}

resource "kubernetes_config_map" "grafana-injected-config" {
  metadata {
    name = "grafana-injected-config"
    namespace  = kubernetes_namespace_v1.monitoring-namespace.id
    labels = {
      grafana_datasource = "inject_me" # If this is set, Grafana will load this config map automatically (*)
    }
  }

  data = {
    "datasource.yaml" =  <<EOF
        apiVersion: 1
        datasources:
        - name: Prometheus-Default
          type: prometheus
          url: http://prometheus-server.monitoring.svc.cluster.local
          access: proxy
          isDefault: true
        EOF
  }

}

resource "helm_release" "grafana" {
  name       = "grafana"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "grafana"
  namespace  = kubernetes_namespace_v1.monitoring-namespace.id

  set {
    name  = "persistence.storageClassName"
    value = "gp2"
  }

  set {
    name  = "persistence.enabled"
    value = true
  }

  set {
    name  = "adminPassword"
    value = "EKS!sAWSome"
  }  

  # inject config with the label grafana_datasource, refer https://github.com/grafana/helm-charts/blob/main/charts/grafana/values.yaml
  set {
    name  = "sidecar.datasources.enabled" 
    value = true
  }  

  set {
    name  = "sidecar.datasources.label"
    value = "grafana_datasource"
  }    

  set {
    name  = "sidecar.datasources.labelValue"
    value = "inject_me"    
  }

  set {
    name  = "sidecar.datasources.searchNamespace"
    value = kubernetes_namespace_v1.monitoring-namespace.id
  }    

  depends_on = [ helm_release.prometheus, kubernetes_config_map.grafana-injected-config ]

}