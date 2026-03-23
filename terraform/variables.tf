variable "region" {
  default = "ams3"
}

variable "ssh_key_name" {
  description = "Name of the SSH key already in your DigitalOcean account"
  type        = string
}

variable "control_plane_size" {
  default = "s-1vcpu-1gb"
}

variable "worker_size" {
  default = "s-1vcpu-2gb"
}

variable "control_plane_name" {
  default = "do-k3s-control"
}

variable "worker_names" {
  type    = list(string)
  default = ["do-k3s-worker-1", "do-k3s-worker-2", "do-k3s-worker-3"]
}
