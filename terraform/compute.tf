resource "digitalocean_vpc" "k3s_vpc" {
  name   = "k3s-vpc"
  region = var.region
}

resource "digitalocean_kubernetes_cluster" "primary" {
  name    = "do-k3s-cluster"
  region  = var.region
  version = "1.35.1-do.0"
  vpc_uuid = digitalocean_vpc.k3s_vpc.id

  node_pool {
    name       = "worker-pool"
    size       = var.worker_size
    auto_scale = true
    min_nodes  = 1
    max_nodes  = 5
    node_count = 1
  }
}
