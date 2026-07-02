#!/usr/bin/env bash
set -e

mooncake_master \
    --port 50898 \
    --metrics_port 9090 \
    --eviction_high_watermark_ratio 0.9 \
    --eviction_ratio 0.1 \
    --default_kv_lease_ttl 11000 \
    2>&1 | tee run_mooncake.log
