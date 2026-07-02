# DeepSeek V4 Sparse KV LRU Mooncake Experiments

本文档用于在真实 Ascend 服务器上验证 DeepSeek V4 稀疏注意力 top-k 是否具有足够局部性，从而判断后续是否值得实现 Mooncake 后端的稀疏 KV LRU 工作集。

启动脚本刻意保持简单：不做参数化拼接，不自动同时拉起多个进程。每个脚本就是一段可直接调试的命令；如需改模型路径、设备号、端口或日志名，直接编辑对应脚本。

## 脚本说明

- `tools/dsv4_sparse_kv/write_mooncake_config.sh`
  - 写入固定配置 `/vllm-workspace/mydata/mydata/mooncake.json`。
- `tools/dsv4_sparse_kv/start_mooncake_master.sh`
  - 单独启动 `mooncake_master`，日志写到当前目录 `run_mooncake.log`。
- `tools/dsv4_sparse_kv/start_dsv4_baseline.sh`
  - 按用户原始命令启动 DeepSeek V4 + AscendStoreConnector + Mooncake baseline。
  - 日志写到当前目录 `run_dsv4_baseline.log`。
- `tools/dsv4_sparse_kv/start_dsv4_topk_trace.sh`
  - 启动 DeepSeek V4 top-k trace 实验。
  - 默认 eager、`max_num_seqs=1`，trace 写到当前目录 `topk_trace.jsonl`。
  - 日志写到当前目录 `run_dsv4_topk_trace.log`。
- `tools/dsv4_sparse_kv/start_dsv4_no_kv_pool.sh`
  - 启动不带 KV Pool / Mooncake 的对照服务。
  - 日志写到当前目录 `run_dsv4_no_kv_pool.log`。
- `tools/dsv4_sparse_kv/send_dsv4_probe_requests.py`
  - 发送 smoke、shared-prefix、long-decode、mixed 请求。
- `tools/dsv4_sparse_kv/analyze_dsv4_topk_lru.py`
  - 分析 `topk_trace.jsonl` 的相邻 top-k overlap，并离线模拟 LRU 命中率。
- `tools/dsv4_sparse_kv/summarize_dsv4_experiment.py`
  - 汇总日志、请求结果和 LRU 分析结果。

## 通用准备

以下命令中的 `OUT_DIR` 是实验输出目录。服务端脚本会把日志写到当前目录，所以建议先 `cd "$OUT_DIR"` 再启动服务。

```bash
export REPO=/vllm-workspace/vllm-ascend
export OUT_ROOT=/vllm-workspace/mydata/dsv4_sparse_kv_exp

cd "$REPO"
bash tools/dsv4_sparse_kv/write_mooncake_config.sh
```

## 实验 E0：基线 smoke

目的：确认当前分支可以跑通用户原始 DeepSeek V4 + Mooncake 配置。

终端 1：

```bash
export REPO=/vllm-workspace/vllm-ascend
export OUT_DIR=/vllm-workspace/mydata/dsv4_sparse_kv_exp/e0_baseline
mkdir -p "$OUT_DIR"
cd "$OUT_DIR"
bash "$REPO/tools/dsv4_sparse_kv/start_mooncake_master.sh"
```

终端 2：

```bash
export REPO=/vllm-workspace/vllm-ascend
export OUT_DIR=/vllm-workspace/mydata/dsv4_sparse_kv_exp/e0_baseline
mkdir -p "$OUT_DIR"
cd "$OUT_DIR"
bash "$REPO/tools/dsv4_sparse_kv/start_dsv4_baseline.sh"
```

终端 3：

```bash
export REPO=/vllm-workspace/vllm-ascend
export OUT_DIR=/vllm-workspace/mydata/dsv4_sparse_kv_exp/e0_baseline
cd "$REPO"
python tools/dsv4_sparse_kv/send_dsv4_probe_requests.py \
  --base-url http://127.0.0.1:8900 \
  --model dsv4 \
  --out-dir "$OUT_DIR" \
  --scenario smoke \
  --rounds 1 \
  --concurrency 1 \
  --max-tokens 64
python tools/dsv4_sparse_kv/summarize_dsv4_experiment.py --out-dir "$OUT_DIR"
```

## 实验 E1：shared-prefix / KV Pool 复用

目的：确认当前 AscendStoreConnector + Mooncake 的块级/prefix 级复用链路稳定。

终端 1 启动 Mooncake，终端 2 启动 `start_dsv4_baseline.sh`，但把输出目录换成：

```bash
export OUT_DIR=/vllm-workspace/mydata/dsv4_sparse_kv_exp/e1_shared_prefix
```

终端 3：

```bash
export REPO=/vllm-workspace/vllm-ascend
export OUT_DIR=/vllm-workspace/mydata/dsv4_sparse_kv_exp/e1_shared_prefix
cd "$REPO"
python tools/dsv4_sparse_kv/send_dsv4_probe_requests.py \
  --base-url http://127.0.0.1:8900 \
  --model dsv4 \
  --out-dir "$OUT_DIR" \
  --scenario shared-prefix \
  --rounds 3 \
  --concurrency 1 \
  --max-tokens 128 \
  --prompt-repeat 80
python tools/dsv4_sparse_kv/summarize_dsv4_experiment.py --out-dir "$OUT_DIR"
```

## 实验 E2：DSA top-k trace + LRU 模拟

目的：记录 DSA decode top-k，并判断 512、1K、2K、4K、8K 稀疏索引容量下的 LRU 命中率。

终端 1：

```bash
export REPO=/vllm-workspace/vllm-ascend
export OUT_DIR=/vllm-workspace/mydata/dsv4_sparse_kv_exp/e2_topk_trace
mkdir -p "$OUT_DIR"
cd "$OUT_DIR"
bash "$REPO/tools/dsv4_sparse_kv/start_mooncake_master.sh"
```

终端 2：

```bash
export REPO=/vllm-workspace/vllm-ascend
export OUT_DIR=/vllm-workspace/mydata/dsv4_sparse_kv_exp/e2_topk_trace
mkdir -p "$OUT_DIR"
cd "$OUT_DIR"
bash "$REPO/tools/dsv4_sparse_kv/start_dsv4_topk_trace.sh"
```

终端 3：

```bash
export REPO=/vllm-workspace/vllm-ascend
export OUT_DIR=/vllm-workspace/mydata/dsv4_sparse_kv_exp/e2_topk_trace
cd "$REPO"
python tools/dsv4_sparse_kv/send_dsv4_probe_requests.py \
  --base-url http://127.0.0.1:8900 \
  --model dsv4 \
  --out-dir "$OUT_DIR" \
  --scenario long-decode \
  --rounds 1 \
  --concurrency 1 \
  --max-tokens 256 \
  --prompt-repeat 120
python tools/dsv4_sparse_kv/analyze_dsv4_topk_lru.py \
  --trace "$OUT_DIR/topk_trace.jsonl" \
  --out-dir "$OUT_DIR" \
  --phase decode \
  --capacities 512,1024,2048,4096,8192 \
  --compress-ratio 4
python tools/dsv4_sparse_kv/summarize_dsv4_experiment.py --out-dir "$OUT_DIR"
```

## 实验 E3：关闭 KV Pool 对照

目的：区分 KV Pool / Mooncake 本身的问题和 DeepSeek V4 推理路径的问题。

终端 1：

```bash
export REPO=/vllm-workspace/vllm-ascend
export OUT_DIR=/vllm-workspace/mydata/dsv4_sparse_kv_exp/e3_no_kv_pool
mkdir -p "$OUT_DIR"
cd "$OUT_DIR"
bash "$REPO/tools/dsv4_sparse_kv/start_dsv4_no_kv_pool.sh"
```

终端 2：

```bash
export REPO=/vllm-workspace/vllm-ascend
export OUT_DIR=/vllm-workspace/mydata/dsv4_sparse_kv_exp/e3_no_kv_pool
cd "$REPO"
python tools/dsv4_sparse_kv/send_dsv4_probe_requests.py \
  --base-url http://127.0.0.1:8900 \
  --model dsv4 \
  --out-dir "$OUT_DIR" \
  --scenario smoke \
  --rounds 1 \
  --concurrency 1 \
  --max-tokens 64
python tools/dsv4_sparse_kv/summarize_dsv4_experiment.py --out-dir "$OUT_DIR"
```

## 回传给 Codex 的文件

每个实验目录优先回传：

- `experiment_summary.md`
- `experiment_summary.json`
- `probe_summary.json`
- `run_dsv4_baseline.log`、`run_dsv4_topk_trace.log` 或 `run_dsv4_no_kv_pool.log` 的最后 200 行
- `run_mooncake.log` 的最后 100 行
- `topk_lru_summary.md` 和 `topk_lru_summary.json`，仅 E2 有

如果 E2 的 `topk_trace.jsonl` 很大，先不要传原始 trace；先传 LRU summary 即可。
