#!/bin/bash
# Generate ansible/inventory-do.yml from terraform outputs

CONTROL_IP=$(terraform output -raw control_plane_ip)
WORKER_IPS=$(terraform output -json worker_ips | jq -r '.[]')

cat <<EOF > ../ansible/inventory-do.yml
all:
  hosts:
    localhost:
      ansible_connection: local
      ansible_python_interpreter: "{{ ansible_playbook_python }}"

  vars:
    control_node_user: "root"
    ssh_key_path: "~/.ssh/klti"
    kubeconfig_path: "~/.kube/do-k3s.yaml"
    repo_root: "{{ playbook_dir | dirname }}"
    cloud_provider: "do"
    ansible_user: "root"
    ansible_ssh_private_key_file: "{{ ssh_key_path }}"
    base_domain: "homelab.kenchlightyear.com"

  children:
    control:
      hosts:
        ${CONTROL_IP}:
    workers:
      hosts:
EOF

for ip in $WORKER_IPS; do
  echo "        ${ip}:" >> ../ansible/inventory-do.yml
done
