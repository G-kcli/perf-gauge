#!/bin/bash

# See go/perf-gauge-gcs-setup

REGION=us-east1
SIZE="100K"

PREFIX=baseline

CONCURRENCY=20 # i.e. the number of connections
RATE=100 # QPS

size=$(echo ${SIZE} | awk '{print tolower($0)}')

BUCKET="${PREFIX}-${REGION}-probe-${size}"
METRIC_NAME=${REGION}-read-${size}

# choose if we want the regional or the global endpoint
GCS_URL="https://storage.googleapis.com/download/storage/v1/b"

PROMETHEUS_ADDR="10.128.15.226:9091"

rm objects-temp-${METRIC_NAME}.txt
# List up to 256,000 objects
for ((i = 0; i < 256; i++)); do
  digit=$(printf "%02X" ${i} | awk '{print tolower($0)}')
  echo "Listing ${BUCKET}/${digit}**"
  gsutil ls gs://${BUCKET}/${digit}** | sed -r "s/gs:\/\/${BUCKET}\///g" >>objects-temp-${METRIC_NAME}.txt
done

while true; do
  TOKEN=$(gcloud auth application-default print-access-token)

  # shuffle
  cat objects-temp-${METRIC_NAME}.txt | shuf >objects-get-${METRIC_NAME}.txt

  # let take only the first 5k objects
  OBJECTS=($(cat ./objects-get-${METRIC_NAME}.txt | head -n 5000))
  URLS=""
  for object in "${OBJECTS[@]}"; do
    escaped_object=$(echo "${object}" | sed "s/\//%2F/g")
    URLS="${URLS} ${GCS_URL}/${BUCKET}/o/${escaped_object}?alt=media"
  done
  echo "TOKEN: ${TOKEN}"

  perf-gauge \
    --name ${METRIC_NAME} \
    --concurrency ${CONCURRENCY} --rate ${RATE} \
    --request_timeout 1m \
    --max_iter 30 \
    --duration 1m \
    --continuous \
    --prometheus ${PROMETHEUS_ADDR} \
    http ${URLS} \
    -H "Authorization: Bearer ${TOKEN}" \
    -E 401 -E 403 \
    --conn_reuse | sed /Unauth/q
done