#!/bin/bash

source ../.env

cp ../confs/chatLanguageModels{,.public}.json
sed -i "s|${LOCAL_URL}|${PUBLIC_URL}|g" ../confs/chatLanguageModels.public.json

docker compose down
cat ./router/* > router.ini
docker compose up -d
docker logs -f llama-cpp
