#!/bin/bash

docker compose down
cat ./router/* > router.ini
docker compose up -d
docker logs -f llama-cpp
