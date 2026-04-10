#!/bin/bash
set -euo pipefail

ROCBLAS_SRC=${ROCBLAS_SRC:-$HOME/rocblas-build}
MAX_JOBS=${MAX_JOBS:-24}
LOG=${LOG:-$ROCBLAS_SRC/rocblas_build.log}
exec > >(tee -a "$LOG") 2>&1

echo "=== rocBLAS gfx1010 build started: $(date) ==="

export ROCM_PATH=/opt/rocm
export PATH=/opt/rocm/bin:$PATH
export HIP_PATH=/opt/rocm

cd "$ROCBLAS_SRC"

python3 rmake.py \
  --architecture gfx1010 \
  -j "$MAX_JOBS" \
  --no-msgpack \
  -i

echo "=== rocBLAS build complete: $(date) ==="
ls "$ROCBLAS_SRC/build/release/rocblas-install/lib/rocblas/library/" | grep gfx1010 | head -5
