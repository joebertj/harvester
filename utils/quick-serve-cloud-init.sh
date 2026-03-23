#!/usr/bin/env bash
set -e

REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)
CLOUD_INIT_DIR="$REPO_ROOT/cloud-init"

if [ ! -d "$CLOUD_INIT_DIR" ]; then
    echo "❌ Error: Directory not found at $CLOUD_INIT_DIR"
    exit 1
fi

echo "🚀 Starting Python HTTP server on port 80 to serve cloud-init files..."
echo "⚠️  You may be prompted for your sudo password due to port 80 binding."

cd "$CLOUD_INIT_DIR"

# Start the python server in the background
sudo python3 -m http.server 80 &
SERVER_PID=$!

# Trap Ctrl+C to clean up the background process
trap 'echo -e "\n🛑 Stopping HTTP server..."; sudo kill $SERVER_PID; exit 0' SIGINT SIGTERM

echo "✅ Server running! Waiting for requests..."

# Match MacOS or Linux local IP
LOCAL_IP=$(ipconfig getifaddr en0 2>/dev/null || hostname -I 2>/dev/null | awk '{print $1}')

echo ""
echo "You can provide the following URLs to your booting Harvester VMs:"
for file in *.yaml; do
    echo "  👉 http://${LOCAL_IP:-127.0.0.1}/${file}"
done
echo ""

# Quick health check
sleep 2 && curl -s http://127.0.0.1/work-1.yaml > /dev/null && echo "Internal test fetch: SUCCESS"

echo "Press Ctrl+C to stop the server."
wait $SERVER_PID
