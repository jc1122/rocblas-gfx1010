# rocBLAS gfx1010 patch (AMD RX 5700 XT / RDNA1)

Enables rocBLAS matmul support for **gfx1010** (AMD RX 5700 XT, Navi 10, RDNA1), which is not officially supported by any rocBLAS release.

Most users should not install this repo directly. Run the `pytorch-gfx1010` installer, which installs this rocBLAS layer automatically when needed.

## Install

Use the installer:

```bash
curl -sSL https://raw.githubusercontent.com/jc1122/rocblas-gfx1010/main/install.sh | bash
```

This installs the gfx1010 rocBLAS runtime into `/opt/rocm`. On a normal system install, it
will use `sudo` for the final copy step.

Do **not** expect `pytorch-gfx1010` to provide BLAS support by itself. Matmul, `nn.Linear`,
and `bmm` require this modified rocBLAS runtime as a separate system-level dependency.

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

## Supported install modes

```bash
# Release install (default, fast)
curl -sSL https://raw.githubusercontent.com/jc1122/rocblas-gfx1010/main/install.sh | bash

# Source-build fallback
curl -sSL https://raw.githubusercontent.com/jc1122/rocblas-gfx1010/main/install.sh | \
  MODE=build bash
```

`MODE=release` installs a prebuilt runtime tarball from GitHub Releases. `MODE=build` clones
`ROCm/rocBLAS` `rocm-6.4.0`, copies in the `navi10_logic` YAML files from this repo, builds
the runtime, and installs it into `/opt/rocm`.

The installer backs up the current rocBLAS runtime under
`~/.cache/rocblas-gfx1010/backups/<timestamp>/` before replacing:

- `/opt/rocm/lib/librocblas.so*`
- `/opt/rocm/lib/rocblas/library/`

## Runtime contents

The release tarball contains the runtime subset needed for gfx1010 matmul support:

- `lib/librocblas.so*`
- `lib/rocblas/library/`

It does not replace unrelated ROCm components.

## Tested with

- AMD RX 5700 XT (gfx1010, Navi 10, RDNA1)
- ROCm 6.4.0
- PyTorch 2.9.1 built from source with `PYTORCH_ROCM_ARCH=gfx1010`
  (see [pytorch-gfx1010](https://github.com/jc1122/pytorch-gfx1010) for the PyTorch patch)
