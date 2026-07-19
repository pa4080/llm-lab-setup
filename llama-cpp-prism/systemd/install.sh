#!/usr/bin/env bash
set -euo pipefail

SERVICE_DIR="/mnt/data/llm-lab/llama-cpp-prism/systemd"
SERVICE_FILE="${SERVICE_DIR}/llama-cpp-prism.service"
DEST="/etc/systemd/system/llama-cpp-prism.service"

# Use whoami to get the real user (not affected by sudo)
SERVICE_USER=$(whoami)
SERVICE_WORK_DIR="$(pwd)"

echo "Installing llama-cpp-prism systemd service..."
echo "  User: ${SERVICE_USER}"
echo "  Working Directory: ${SERVICE_WORK_DIR}"

# Substitute variables directly (no envsubst needed)
sed \
  -e "s|User=\${SERVICE_USER}|User=${SERVICE_USER}|"\
  -e "s|Group=\${SERVICE_USER}|Group=${SERVICE_USER}|"\
  -e "s|WorkingDirectory=\${SERVICE_WORK_DIR}|WorkingDirectory=${SERVICE_WORK_DIR}|"\
  -e "s|EnvironmentFile=\${SERVICE_WORK_DIR}\/../\.env|EnvironmentFile=${SERVICE_WORK_DIR}/../.env|" \
  -e "s|ExecStart=\${SERVICE_WORK_DIR}/serve.sh|ExecStart=${SERVICE_WORK_DIR}/serve.sh|" \
  "${SERVICE_FILE}" | sudo tee "${DEST}"

echo "  Copied to: ${DEST}"

systemctl daemon-reload
echo "  daemon-reload done."

echo ""
echo "Service installed. Choose an action:"
echo "  1) Enable and start now"
echo "  2) Just enable (start manually later)"
echo "  3) Skip"
read -r choice

case "${choice}" in
  1)
    systemctl enable --now llama-cpp-prism
    echo ""
    echo "Service enabled and started."
    echo "Check the service status with:"
    echo "systemctl status llama-cpp-prism.service"
    ;;
  2)
    systemctl enable llama-cpp-prism
    echo ""
    echo "Service enabled. Start with: systemctl start llama-cpp-prism"
    ;;
  3)
    echo ""
    echo "Installation complete. Run manually:"
    echo "  systemctl enable llama-cpp-prism"
    echo "  systemctl start llama-cpp-prism"
    ;;
esac
