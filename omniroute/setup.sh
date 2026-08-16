#!/bin/bash

if [[ -f ../.env ]]; then
  source ../.env
fi

CONFS_DIR="confs"

if [[ ! -d "$CONFS_DIR" ]]; then
	mkdir -p "$CONFS_DIR"
fi

SIGNATURE="WEB"
OMNI_JSON_WEB="${CONFS_DIR}/${SIGNATURE}-omniroute-models.json"
API_KEY_VAR="OMNI_API_KEY_${SIGNATURE}"


curl -s "${OMNI_REMOTE_API_MODELS}" \
  -H "Authorization: Bearer ${!API_KEY_VAR}" \
  | jq '[.data[]]' | tee "$OMNI_JSON_WEB"
  # | jq '[.data[] | select(.parent == null)]' | tee "$OMNI_JSON_WEB"

echo ""
echo "Generating configs..."
../scripts/omniroute-generate-config.sh --prefix "$SIGNATURE" --input "$OMNI_JSON_WEB"
