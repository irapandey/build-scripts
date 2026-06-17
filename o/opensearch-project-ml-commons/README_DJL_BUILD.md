# DJL PyTorch Build for ml-commons

This directory contains scripts for building ml-commons with DJL PyTorch support on ppc64le architecture.

## Overview

The build process has been split into two parts:
1. **DJL PyTorch Build** - Standalone script to build DJL v0.33.0 with PyTorch v2.1.2
2. **ml-commons Build** - Main build script that can use pre-built DJL or build it inline

## Files

- `build_djl_pytorch_v2.1.2.sh` - Standalone script to build DJL with PyTorch v2.1.2
- `ml-commons_3.5.0.0_ubi9.7.sh` - Main ml-commons build script (updated to support pre-built DJL)
- `djl_v0.33.0.patch` - Patch file for DJL v0.33.0
- `ml-commons_3.5.0.0.patch` - Patch file for ml-commons
- `onnxruntime_v1.17.1.patch` - Patch file for ONNX Runtime

## Quick Start

### Option 1: Build Everything (Recommended for First Time)

```bash
# Build ml-commons with inline DJL build
bash ml-commons_3.5.0.0_ubi9.7.sh
```

### Option 2: Two-Step Build (Recommended for Development)

```bash
# Step 1: Build DJL once (takes ~30-45 minutes)
bash build_djl_pytorch_v2.1.2.sh

# Step 2: Build ml-commons using pre-built DJL (faster subsequent builds)
bash ml-commons_3.5.0.0_ubi9.7.sh --use-prebuilt-djl
```

## Detailed Usage

### Building DJL Standalone

The standalone DJL build script creates a reusable DJL installation:

```bash
bash build_djl_pytorch_v2.1.2.sh
```

**What it does:**
- Installs PyTorch v2.1.2 from IBM wheels
- Builds DJL v0.33.0 with PyTorch engine
- Publishes to Maven local repository (~/.m2/repository)
- Creates installation at `~/.local/djl-pytorch-1.13.1/`

**Output:**
- Native libraries: `~/.local/djl-pytorch-2.1.2/lib/`
- Maven artifacts: `~/.m2/repository/ai/djl/`
- Environment setup: `~/.local/djl-pytorch-2.1.2/setup-env.sh`

### Building ml-commons

#### With Pre-built DJL (Faster)

```bash
bash ml-commons_3.5.0.0_ubi9.7.sh --use-prebuilt-djl
```

This option:
- Skips DJL build (saves 30-45 minutes)
- Uses DJL from `~/.local/djl-pytorch-2.1.2/`
- Requires DJL to be built first using `build_djl_pytorch_v2.1.2.sh`

#### Without Pre-built DJL (Default)

```bash
bash ml-commons_3.5.0.0_ubi9.7.sh
```

This option:
- Builds DJL inline (if standalone script exists, uses it)
- Takes longer but doesn't require pre-built DJL
- Good for one-time builds or CI/CD

#### Skip Tests

```bash
bash ml-commons_3.5.0.0_ubi9.7.sh --skip-tests
bash ml-commons_3.5.0.0_ubi9.7.sh --use-prebuilt-djl --skip-tests
```

#### Specify Version

```bash
bash ml-commons_3.5.0.0_ubi9.7.sh 3.5.0.0
bash ml-commons_3.5.0.0_ubi9.7.sh 3.5.0.0 --use-prebuilt-djl
```

## Key Changes from Original Script

### PyTorch Version
- **Using:** PyTorch 2.1.2
- **Reason:** Required version for DJL v0.33.0 on ppc64le

### Build Process
- **Added:** Standalone DJL build script
- **Added:** `--use-prebuilt-djl` flag for faster rebuilds
- **Fixed:** CMake configuration for libtorch (copies share/cmake from Python torch)
- **Improved:** Error handling and build verification

### Directory Structure
```
~/.local/djl-pytorch-2.1.2/     # DJL installation
├── lib/                          # Native libraries
│   ├── libtorch*.so
│   ├── libprotobuf.so.25.3.0
│   ├── libopenblas.so.0
│   └── libabsl_*.so*
├── maven/                        # Maven artifacts (backup)
├── setup-env.sh                  # Environment setup script
└── README.md                     # Installation documentation

~/.m2/repository/ai/djl/          # Maven local repository
├── api/
├── pytorch-engine/
├── pytorch-native-auto/
└── ...

~/.djl.ai/pytorch/2.1.2-cpu-linux-ppc64le/  # DJL runtime
└── (native libraries)
```

## Environment Variables

When using pre-built DJL, these variables are automatically set:

```bash
export LD_LIBRARY_PATH="~/.local/djl-pytorch-2.1.2/lib:$LD_LIBRARY_PATH"
export JAVA_OPTS="-Dorg.opensearch.djl.pytorch.path=~/.local/djl-pytorch-2.1.2/lib"
export JAVA_OPTS="$JAVA_OPTS -Djava.library.path=~/.local/djl-pytorch-2.1.2/lib"
export JAVA_OPTS="$JAVA_OPTS -Dengine.pytorch.disable_native_extraction=true"
```

## Troubleshooting

### CMake Cannot Find Torch

**Error:**
```
CMake Error: Could not find a package configuration file provided by "Torch"
```

**Solution:**
This is fixed in the updated script. The script now copies the complete `share/cmake/Torch/` directory from the Python torch installation.

### Pre-built DJL Not Found

**Error:**
```
ERROR: DJL Maven artifacts not found in ~/.m2/repository/ai/djl
```

**Solution:**
```bash
# Build DJL first
bash build_djl_pytorch_v2.1.2.sh

# Then build ml-commons
bash ml-commons_3.5.0.0_ubi9.7.sh --use-prebuilt-djl
```

### Library Not Found at Runtime

**Error:**
```
java.lang.UnsatisfiedLinkError: no torch_jni in java.library.path
```

**Solution:**
```bash
# Source the DJL environment
source ~/.local/djl-pytorch-2.1.2/setup-env.sh

# Or set manually
export LD_LIBRARY_PATH=~/.local/djl-pytorch-2.1.2/lib:$LD_LIBRARY_PATH
```

## Build Times (Approximate)

- **DJL Build:** 30-45 minutes
- **ml-commons with pre-built DJL:** 15-20 minutes
- **ml-commons without pre-built DJL:** 45-60 minutes

## Dependencies

### System Packages
- java-17-openjdk-devel (for ONNX Runtime)
- java-21-openjdk-devel (for DJL and ml-commons)
- gcc, gcc-c++, gcc-gfortran
- cmake, make
- python3.9-devel, python3.9-pip
- openblas-devel
- zlib-devel, openssl-devel, libffi-devel

### Python Packages
- torch==2.1.2 (from IBM wheels)
- abseil_cpp==20240116.2
- libprotobuf==4.25.3
- numpy<2.0
- packaging, wheel, setuptools

### Rust
- rustc 1.87 (for tokenizers)

## CI/CD Integration

For CI/CD pipelines, use the two-step approach:

```bash
# Cache the DJL build
if [ ! -d "$HOME/.local/djl-pytorch-2.1.2" ]; then
    bash build_djl_pytorch_v2.1.2.sh
fi

# Build ml-commons
bash ml-commons_3.5.0.0_ubi9.7.sh --use-prebuilt-djl --skip-tests
```

## Support

For issues or questions:
1. Check the troubleshooting section above
2. Review build logs in `build_workspace/`
3. Verify all dependencies are installed
4. Ensure you're using UBI 9.7 or compatible OS

## License

Apache License, Version 2.0 or later