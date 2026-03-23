output "cluster_endpoint" {
  value = digitalocean_kubernetes_cluster.primary.endpoint
}

output "cluster_urn" {
  value = digitalocean_kubernetes_cluster.primary.urn
}

resource "local_file" "kubeconfig" {
  content  = digitalocean_kubernetes_cluster.primary.kube_config[0].raw_config
  filename = "${path.module}/../ansible/do-k3s.yaml"
}
