# Endpoints

```bash
curl -s -X GET "https://omniapi.spasov.me/v1/models" \
  -H "Content-Type: application/json" | jq
```

```bash
curl -s -X GET "https://omniapi.spasov.me/v1/models?configuredOnly=true" \
  -H "Content-Type: application/json" | jq
```

```bash
curl -s "https://omniapi.spasov.me/v1/models" \
  -H "Authorization: Bearer $OMNI_API_KEY" | jq '.data | length'
```

```bash
curl -s "https://omniapi.spasov.me/v1/models" \
  -H "Authorization: Bearer $OMNI_API_KEY" \
  | jq '[.data[] | select(.parent == null)]' | tee omniroute/omniroute-models.json
```
