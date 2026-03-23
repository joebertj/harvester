#!/usr/bin/env bash
set -e

# Get the absolute path to the repository root so the script can be run from anywhere
REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)
DEST_DIR="$HOME/Library/Mobile Documents/com~apple~CloudDocs/Homelab-Secrets"

echo "Creating backup folder in iCloud Drive..."
mkdir -p "$DEST_DIR"

echo "Backing up Vault initialization keys..."
if [ -f "$REPO_ROOT/ingress/vault/vault-init.json" ]; then
    cp "$REPO_ROOT/ingress/vault/vault-init.json" "$DEST_DIR/"
    echo "✅ vault-init.json safely copied to iCloud."
else
    echo "⚠️ vault-init.json not found! Keep in mind it's only generated after Vault is deployed."
fi

echo "Backing up Ansible secrets environment..."
if [ -f "$REPO_ROOT/ansible/secrets.env" ]; then
    cp "$REPO_ROOT/ansible/secrets.env" "$DEST_DIR/"
    echo "✅ secrets.env safely copied to iCloud."
else
    echo "⚠️ secrets.env not found!"
fi

echo "Backup complete!"