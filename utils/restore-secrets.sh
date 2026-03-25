#!/usr/bin/env bash
set -e

# Get the absolute path to the repository root so the script can be run from anywhere
REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)
SRC_DIR="$HOME/Library/Mobile Documents/com~apple~CloudDocs/Homelab-Secrets"

echo "Checking restore source in iCloud Drive..."
if [ ! -d "$SRC_DIR" ]; then
    echo "❌ Source directory not found in iCloud: $SRC_DIR"
    exit 1
fi

echo "Restoring Vault initialization keys..."
if [ -f "$SRC_DIR/vault-init.json" ]; then
    mkdir -p "$REPO_ROOT/ingress/vault"
    cp "$SRC_DIR/vault-init.json" "$REPO_ROOT/ingress/vault/"
    echo "✅ vault-init.json restored to repository."
else
    echo "ℹ️ vault-init.json not found in backup."
fi

echo "Restoring Ansible secrets environment..."
if [ -f "$SRC_DIR/secrets.env" ]; then
    mkdir -p "$REPO_ROOT/ansible"
    cp "$SRC_DIR/secrets.env" "$REPO_ROOT/ansible/"
    echo "✅ secrets.env restored to repository."
else
    echo "ℹ️ secrets.env not found in backup."
fi

echo "Restoring DigitalOcean Vault initialization keys..."
if [ -f "$SRC_DIR/do-vault-init.json" ]; then
    mkdir -p "$REPO_ROOT/ingress/vault/do"
    cp "$SRC_DIR/do-vault-init.json" "$REPO_ROOT/ingress/vault/do/vault-init.json"
    echo "✅ do-vault-init.json restored to repository (as vault-init.json)."
else
    echo "ℹ️ DigitalOcean vault-init.json not found in backup."
fi

echo "Restoration complete! 🚀"
