#!/usr/bin/env bash
set -euo pipefail

SERVICE_DIR="/mnt/data/llm-lab/llama-cpp-prism/systemd"
SERVICE_FILE="${SERVICE_DIR}/llama-cpp-prism.service"
DEST="/etc/systemd/system/llama-cpp-prism.service"

echo "Installing llama-cpp-prism systemd service..."
cp "${SERVICE_FILE}" "${DEST}"
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
