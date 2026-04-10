#!/bin/bash
# install.sh — Install rocBLAS gfx1010 runtime for AMD RX 5700 XT / RDNA1.

set -euo pipefail

ROCM_PATH=${ROCM_PATH:-/opt/rocm}
MODE=${MODE:-release}
FORCE_REINSTALL=${FORCE_REINSTALL:-0}
REPO_URL=${REPO_URL:-https://github.com/jc1122/rocblas-gfx1010.git}
RELEASE_TAG=${RELEASE_TAG:-rocm-6.4.0-gfx1010}
ASSET_NAME=${ASSET_NAME:-rocblas-gfx1010-rocm6.4.0-ubuntu24.04-runtime.tar.gz}
ASSET_URL=${ASSET_URL:-https://github.com/jc1122/rocblas-gfx1010/releases/download/${RELEASE_TAG}/${ASSET_NAME}}
SHA256_URL=${SHA256_URL:-https://github.com/jc1122/rocblas-gfx1010/releases/download/${RELEASE_TAG}/SHA256SUMS}
BUILD_DIR=${BUILD_DIR:-$HOME/rocblas-build}
PATCH_REPO_DIR=${PATCH_REPO_DIR:-}
BACKUP_ROOT=${BACKUP_ROOT:-$HOME/.cache/rocblas-gfx1010/backups}
MAX_JOBS=${MAX_JOBS:-24}

TARGET_YAML="$ROCM_PATH/lib/rocblas/library/TensileLibrary_lazy_gfx1010.yaml"

echo "=== rocBLAS gfx1010 install ==="
echo "Mode: $MODE"
echo "ROCm path: $ROCM_PATH"

run_as_root() {
    if [ -w "$ROCM_PATH" ] && [ -w "$ROCM_PATH/lib" ]; then
        "$@"
    else
        sudo "$@"
    fi
}

is_installed() {
    [ -f "$TARGET_YAML" ]
}

backup_existing() {
    local backup_dir=$1

    mkdir -p "$backup_dir/lib/rocblas"

    if compgen -G "$ROCM_PATH/lib/librocblas.so*" >/dev/null; then
        run_as_root cp -a "$ROCM_PATH"/lib/librocblas.so* "$backup_dir/lib/"
    fi

    if [ -d "$ROCM_PATH/lib/rocblas/library" ]; then
        run_as_root cp -a "$ROCM_PATH/lib/rocblas/library" "$backup_dir/lib/rocblas/"
    fi
}

install_runtime_from_dir() {
    local runtime_root=$1
    local backup_dir=$2

    if [ ! -f "$runtime_root/lib/librocblas.so.4.4" ]; then
        echo "ERROR: missing librocblas runtime in $runtime_root"
        exit 1
    fi
    if [ ! -f "$runtime_root/lib/rocblas/library/TensileLibrary_lazy_gfx1010.yaml" ]; then
        echo "ERROR: missing gfx1010 Tensile library in $runtime_root"
        exit 1
    fi

    mkdir -p "$BACKUP_ROOT"
    backup_existing "$backup_dir"

    run_as_root mkdir -p "$ROCM_PATH/lib/rocblas"
    run_as_root rm -f "$ROCM_PATH"/lib/librocblas.so*
    run_as_root rm -rf "$ROCM_PATH/lib/rocblas/library"
    run_as_root cp -a "$runtime_root"/lib/librocblas.so* "$ROCM_PATH/lib/"
    run_as_root cp -a "$runtime_root"/lib/rocblas/library "$ROCM_PATH/lib/rocblas/"
}

install_from_release() {
    local tmpdir=$1
    local asset_path="$tmpdir/$ASSET_NAME"
    local sha_path="$tmpdir/SHA256SUMS"

    curl -fsSL "$ASSET_URL" -o "$asset_path"
    curl -fsSL "$SHA256_URL" -o "$sha_path"

    (
        cd "$tmpdir"
        grep "  $ASSET_NAME\$" "$sha_path" | sha256sum -c -
    )

    tar -C "$tmpdir" -xzf "$asset_path"
    install_runtime_from_dir "$tmpdir/rocblas-gfx1010-runtime" "$BACKUP_ROOT/$(date +%Y%m%d-%H%M%S)"
}

install_from_build() {
    local tmpdir=$1
    local patch_repo=$PATCH_REPO_DIR

    if [ -z "$patch_repo" ]; then
        patch_repo="$tmpdir/rocblas-gfx1010"
        git clone --depth 1 "$REPO_URL" "$patch_repo"
    fi

    if [ ! -d "$patch_repo/navi10_logic" ]; then
        echo "ERROR: missing navi10_logic in $patch_repo"
        exit 1
    fi

    if [ ! -d "$BUILD_DIR/.git" ]; then
        git clone --branch rocm-6.4.0 --depth 1 https://github.com/ROCm/rocBLAS "$BUILD_DIR"
    fi

    mkdir -p "$BUILD_DIR/library/src/blas3/Tensile/Logic/asm_full/navi10"
    cp "$patch_repo"/navi10_logic/*.yaml "$BUILD_DIR/library/src/blas3/Tensile/Logic/asm_full/navi10/"

    ROCBLAS_SRC="$BUILD_DIR" MAX_JOBS="$MAX_JOBS" "$patch_repo/build_gfx1010.sh"
    install_runtime_from_dir "$BUILD_DIR/build/release/rocblas-install" "$BACKUP_ROOT/$(date +%Y%m%d-%H%M%S)"
}

if [ ! -f "$ROCM_PATH/bin/hipcc" ]; then
    echo "ERROR: ROCm not found at $ROCM_PATH (set ROCM_PATH if installed elsewhere)"
    exit 1
fi

if is_installed && [ "$FORCE_REINSTALL" != "1" ]; then
    echo "gfx1010 rocBLAS runtime already present at $TARGET_YAML"
    exit 0
fi

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

case "$MODE" in
    release)
        install_from_release "$tmpdir"
        ;;
    build)
        install_from_build "$tmpdir"
        ;;
    *)
        echo "ERROR: MODE must be 'release' or 'build' (got: $MODE)"
        exit 1
        ;;
esac

if ! is_installed; then
    echo "ERROR: gfx1010 rocBLAS install did not produce $TARGET_YAML"
    exit 1
fi

echo ""
echo "Installed gfx1010 rocBLAS runtime."
echo "Verification target: $TARGET_YAML"
echo "Backups stored under: $BACKUP_ROOT"
