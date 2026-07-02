#!/usr/bin/env bash
set -e

mkdir -p /vllm-workspace/mydata/mydata

cat > /vllm-workspace/mydata/mydata/mooncake.json <<'JSON'
{
    "metadata_server": "P2PHANDSHAKE",
    "protocol": "ascend",
    "device_name": "",
    "master_server_address": "127.0.0.1:50898",
    "global_segment_size": "15GB",
    "use_ascend_direct": true
}
JSON

echo "Wrote /vllm-workspace/mydata/mydata/mooncake.json"
