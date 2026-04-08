# rocBLAS gfx1010 patch (AMD RX 5700 XT / RDNA1)

Enables rocBLAS matmul support for **gfx1010** (AMD RX 5700 XT, Navi 10, RDNA1), which is not officially supported by any rocBLAS release.

## Background

rocBLAS uses [Tensile](https://github.com/ROCmSoftwarePlatform/Tensile) to generate GEMM kernels. Official rocBLAS builds only ship Tensile libraries for gfx906, gfx908, gfx90a, gfx1030, gfx1100, etc. — gfx1010 (RDNA1) is absent. Without a TensileLibrary.dat for gfx1010, rocBLAS calls `abort()` on the first matmul.

## What this patch does

Adds 24 Tensile logic YAML files for `navi10` (gfx1010), ported from the official `navi21` (gfx1030) YAML files by:
- Replacing all `gfx1030` → `gfx1010`
- Replacing all `navi21` → `navi10`
- Replacing device ID `73a2` → `731f`
- **Removing all I8/int8 logic files** — gfx1010 has no assembly int8 support; those kernels cause build failures

Supported GEMM types after the patch: `SS` (float32), `DD` (float64), `HH` (float16), `HHS_BH` (mixed precision), `SB`, `HB`, `BB` (bfloat16 variants).

## Requirements

- ROCm 6.4
- rocBLAS source: `git clone --branch rocm-6.4.0 https://github.com/ROCm/rocBLAS`
- Python 3, `tensile` pip package

## Usage

```bash
# Clone rocBLAS 6.4
git clone --branch rocm-6.4.0 --depth 1 https://github.com/ROCm/rocBLAS ~/rocblas-build
cd ~/rocblas-build

# Copy in the navi10 logic files
cp /path/to/this/repo/navi10_logic/*.yaml \
   library/src/blas3/Tensile/Logic/asm_full/navi10/

# Build and install (takes ~10 minutes)
bash /path/to/this/repo/build_gfx1010.sh
```

The build script runs `rmake.py --architecture gfx1010 -j 24 --no-msgpack -i` and installs rocBLAS to `~/rocblas-build/build/release/rocblas-install/`.

Then copy to your ROCm installation:
```bash
sudo cp -r ~/rocblas-build/build/release/rocblas-install/lib/rocblas /opt/rocm/lib/
sudo cp ~/rocblas-build/build/release/rocblas-install/lib/librocblas* /opt/rocm/lib/
sudo cp -r ~/rocblas-build/build/release/rocblas-install/include/rocblas /opt/rocm/include/
```

## Tested with

- AMD RX 5700 XT (gfx1010, Navi 10, RDNA1)
- ROCm 6.4.0
- PyTorch 2.9.1 built from source with `PYTORCH_ROCM_ARCH=gfx1010`
  (see [pytorch-gfx1010](https://github.com/jc1122/pytorch-gfx1010) for the PyTorch patch)
