#!/usr/bin/env bash
set -e

unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY
export OMP_PROC_BIND=false
export OMP_NUM_THREADS=10
export PYTORCH_NPU_ALLOC_CONF=expandable_segments:True
export LD_PRELOAD=/usr/lib64/libjemalloc.so.2:$LD_PRELOAD
export HCCL_BUFFSIZE=1024
export VLLM_ASCEND_ENABLE_FLASHCOMM1=1
export TASK_QUEUE_ENABLE=1
export HCCL_OP_EXPANSION_MODE="AIV"

export ASCEND_RT_VISIBLE_DEVICES=0,1,2,3,4,5,12,13
export PYTHONHASHSEED=0
export MOONCAKE_CONFIG_PATH="/vllm-workspace/mydata/mydata/mooncake.json"
export ASCEND_BUFFER_POOL=4:8
# export ASCEND_CONNECT_TIMEOUT=10000
# export ASCEND_TRANSFER_TIMEOUT=10000
export ACL_OP_INIT_MODE=1
export VLLM_LOGGING_LEVEL=DEBUG

export VLLM_ASCEND_DSV4_TOPK_TRACE_ENABLE=1
export VLLM_ASCEND_DSV4_TOPK_TRACE_PATH="${PWD}/topk_trace.jsonl"
export VLLM_ASCEND_DSV4_TOPK_TRACE_MAX_ROWS=50000
export VLLM_ASCEND_DSV4_TOPK_TRACE_SAMPLE_ROWS=1

vllm serve /data/models/Eco-Tech/DeepSeek-V4-Flash-w8a8-mtp \
    --enable-prefix-caching \
    --no-disable-hybrid-kv-cache-manager \
    --max-model-len 8192 \
    --max-num-batched-tokens 4096 \
    --served-model-name dsv4 \
    --gpu-memory-utilization 0.9 \
    --api-server-count 1 \
    --max-num-seqs 1 \
    --data-parallel-size 2 \
    --tensor-parallel-size 4 \
    --enable-expert-parallel \
    --tokenizer-mode deepseek_v4 \
    --tool-call-parser deepseek_v4 \
    --enable-auto-tool-choice \
    --reasoning-parser deepseek_v4 \
    --safetensors-load-strategy 'prefetch' \
    --model-loader-extra-config='{"enable_multithread_load": "true", "num_threads": 128}' \
    --quantization ascend \
    --port 8900 \
    --block-size 64 \
    --speculative-config '{"num_speculative_tokens": 1,"method": "mtp","enforce_eager": true}' \
    --enforce-eager \
    --async-scheduling \
    --additional-config '
    {"ascend_compilation_config":{
        "enable_npugraph_ex":true,
        "enable_static_kernel":false
        },
    "enable_cpu_binding": true,
    "multistream_overlap_shared_expert":true}' \
    --kv-transfer-config \
    '{
        "kv_connector": "AscendStoreConnector",
        "kv_role": "kv_both",
        "kv_load_failure_policy": "recompute",
        "kv_connector_extra_config": {
            "backend": "mooncake",
            "lookup_rpc_port": "0",
            "load_async": true
        }
    }' \
    2>&1 | tee run_dsv4_topk_trace.log
