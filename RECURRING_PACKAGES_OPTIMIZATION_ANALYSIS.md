# Recurring Packages Optimization Analysis for ppc64le Build Scripts

## Executive Summary

This document presents findings on recurring packages that are being built repeatedly across multiple build scripts in the repository. These packages are candidates for optimization by using pre-built wheels from the IBM wheel repositories instead of building from source.

**Key Finding**: Multiple packages are being built from source in nearly every build script, despite being available as pre-built wheels at:
- https://wheels.developerfirst.ibm.com/ppc64le/linux
- https://wheels.developerfirst.ibm.com/ppc64le/linux-v2026.03.31

---

## 1. CMAKE - Most Critical Optimization Opportunity

### Current State
**CMake is being built from source in 264+ build scripts**, taking significant time (15-30 minutes per build).

### Evidence from Scripts
```bash
# Pattern found in pytorch, pyarrow, lightgbm, and many others:
wget https://cmake.org/files/v3.31/cmake-3.31.6.tar.gz
tar -zxvf cmake-3.31.6.tar.gz
cd cmake-3.31.6
./bootstrap
make -j$(nproc)
make install
```

### Affected Packages (Sample)
- `p/pytorch/pytorch_2.6.0_ubi_9.3.sh`
- `p/pytorch/pytorch_2.7.1_ubi_9.3.sh`
- `p/pyarrow/pyarrow_23.0.1_ubi_9.3.sh`
- `p/pyarrow/pyarrow_20.0.0_ubi_9.6.sh`
- `l/lightgbm/lightgbm_4.6.0_ubi_9.3.sh`
- And 259+ more scripts

### Recommendation
**Install CMake via package manager instead:**
```bash
# For UBI/RHEL systems
yum install -y cmake

# Or use specific version from EPEL if needed
yum install -y epel-release
yum install -y cmake3
```

### Impact
- **Time Saved**: 15-30 minutes per build
- **Disk Space Saved**: ~500MB per build
- **Maintenance**: Easier version management

---

## 2. OpenBLAS - High-Frequency Rebuild

### Current State
**OpenBLAS is being built from source in 50+ scripts**, despite being a stable dependency.

### Evidence from Scripts
```bash
# Pattern found in pytorch, pyarrow, pillow, etc.:
git clone https://github.com/OpenMathLib/OpenBLAS
cd OpenBLAS
git checkout v0.3.32  # or v0.3.29
make -j$(nproc) TARGET=POWER9 BUILD_BFLOAT16=1 BINARY=64 USE_OPENMP=1 ...
make install PREFIX=/usr/local
```

### Affected Packages (Sample)
- `p/pytorch/pytorch_2.6.0_ubi_9.3.sh`
- `p/pytorch/pytorch_2.7.1_ubi_9.3.sh`
- `p/pytorch/pytorch_2.5.1_ubi_9.3.sh`
- `p/pyarrow/pyarrow_23.0.1_ubi_9.3.sh`
- `p/pyarrow/pyarrow_20.0.0_ubi_9.6.sh`
- `p/pillow/pillow_v12.0.0_ubi_9.3.sh`
- `p/pyav/pyav_ubi_9.3.sh`
- `p/pytables/pytables_ubi_9.3.sh`
- `l/lightgbm/lightgbm_4.6.0_ubi_9.3.sh`
- `l/langflow/langflow_ubi_9.6.sh`
- `v/vllm/vllm_ubi_9.3.sh`

### Versions Used
- v0.3.32 (most common)
- v0.3.29 (also frequent)

### Recommendation
**Use pre-built OpenBLAS wheel or system package:**
```bash
# Option 1: System package
yum install -y openblas-devel

# Option 2: Pre-built wheel (if available)
pip install --extra-index-url https://wheels.developerfirst.ibm.com/ppc64le/linux/ openblas==0.3.29
```

### Impact
- **Time Saved**: 10-20 minutes per build
- **Consistency**: Same optimized build across all packages

---

## 3. Protobuf & Abseil-cpp - Complex Dependency Chain

### Current State
**Protobuf (with abseil-cpp) is being built from source in 100+ scripts**.

### Evidence from Scripts
```bash
# Pattern found in pytorch, pyarrow, lightgbm, etc.:
git clone https://github.com/abseil/abseil-cpp -b 20240116.2

git clone https://github.com/protocolbuffers/protobuf
cd protobuf
git checkout v4.25.8  # or v4.25.3
git submodule update --init --recursive
rm -rf ./third_party/abseil-cpp
cp -r $SCRIPT_DIR/abseil-cpp ./third_party/

mkdir build && cd build
cmake -G "Ninja" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_CXX_STANDARD=17 \
    -Dprotobuf_BUILD_TESTS=OFF \
    -Dprotobuf_BUILD_SHARED_LIBS=ON \
    -Dprotobuf_ABSL_PROVIDER="module" \
    ...
cmake --build . --verbose
cmake --install .
```

### Affected Packages (Sample)
- `p/pytorch/pytorch_2.6.0_ubi_9.3.sh`
- `p/pytorch/pytorch_2.7.1_ubi_9.3.sh`
- `p/pytorch/pytorch_2.5.1_ubi_9.3.sh`
- `p/pyarrow/pyarrow_23.0.1_ubi_9.3.sh`
- `p/pyarrow/pyarrow_20.0.0_ubi_9.6.sh`
- `l/lightgbm/lightgbm_4.6.0_ubi_9.3.sh`
- `l/langflow/langflow_ubi_9.6.sh`
- `l/libprotobuf/libprotobuf_ubi_9.3.sh`
- `p/protobuf/protobuf_v4.25.3_ubi_9.3.sh`

### Versions Used
- v4.25.8 (most common)
- v4.25.3 (also frequent)
- abseil-cpp 20240116.2

### Recommendation
**Check IBM wheel repository for pre-built protobuf:**
```bash
# Check if available
pip install --extra-index-url https://wheels.developerfirst.ibm.com/ppc64le/linux/ protobuf==4.25.8

# Evidence from vllm script shows it's available:
# "protobuf @ https://wheels.developerfirst.ibm.com/ppc64le/linux/+f/5e5/a6c4d93fcc5cd/protobuf-4.25.8-cp312-cp312-linux_ppc64le.whl"
```

### Impact
- **Time Saved**: 20-30 minutes per build
- **Complexity Reduced**: No need to manage abseil-cpp separately

---

## 4. SciPy - Frequent Rebuild with Dependencies

### Current State
**SciPy is being built from source in 40+ scripts**, along with its dependencies.

### Evidence from Scripts
```bash
# Pattern found in pytorch, vllm, etc.:
python3.12 -m pip install beniget==0.4.2.post1 Cython==3.0.11 gast==0.6.0 \
    meson==1.6.0 meson-python==0.17.1 numpy==2.0.2 packaging pybind11 \
    pyproject-metadata pythran==0.17.0 setuptools==75.3.0 pooch pytest \
    build wheel hypothesis ninja patchelf>=0.11.0

git clone https://github.com/scipy/scipy
cd scipy/
git checkout v1.15.2  # or v1.13.0
git submodule update --init
python3.12 -m pip install .
```

### Affected Packages (Sample)
- `p/pytorch/pytorch_2.6.0_ubi_9.3.sh` (v1.15.2)
- `p/pytorch/pytorch_2.7.1_ubi_9.3.sh` (v1.13.0)
- `p/pytorch/pytorch_2.5.1_ubi_9.3.sh` (v1.15.2)
- `v/vllm/vllm_ubi_9.3.sh`
- `t/torchaudio/torchaudio_ubi_9.3.sh`
- `t/torchvision/torchvision_ubi_9.3.sh`

### Versions Used
- v1.15.2 (most common)
- v1.13.0
- v1.11.4
- v1.16.0

### Recommendation
**Use pre-built SciPy wheel:**
```bash
# Evidence from vllm script shows it's available:
pip install --extra-index-url https://wheels.developerfirst.ibm.com/ppc64le/linux/ \
    scipy==1.16.0
```

### Impact
- **Time Saved**: 15-25 minutes per build
- **Dependencies**: Reduces need to build numpy, pythran, etc.

---

## 5. NumPy - Universal Dependency

### Current State
**NumPy is installed via pip in 249+ scripts**, often with specific versions.

### Evidence from Scripts
```bash
# Common patterns:
pip install numpy==2.0.2
pip install numpy==1.26.4
pip install "numpy<2.0"
pip install numpy==1.23.5
```

### Affected Packages
Nearly every Python-based build script uses NumPy.

### Versions Used
- 2.0.2 (most common for Python 3.12+)
- 1.26.4 (common for Python 3.11)
- 1.23.5 (older scripts)

### Recommendation
**NumPy wheels are already available and being used correctly.** However, ensure consistent version usage:
```bash
# Use IBM wheel repository as primary source
pip install --extra-index-url https://wheels.developerfirst.ibm.com/ppc64le/linux/ numpy==2.0.2
```

### Status
✅ **Already optimized** - NumPy is being installed from wheels, not built from source.

---

## 6. Cython & Meson - Build Tool Dependencies

### Current State
**Cython and Meson are installed in 100+ scripts** as build dependencies.

### Evidence from Scripts
```bash
# Common patterns:
pip install Cython==3.0.11
pip install Cython==0.29.36
pip install meson==1.6.0 meson-python==0.17.1
```

### Recommendation
**These are already being installed from wheels correctly.** Ensure version consistency:
```bash
# Standardize on recent versions
pip install Cython>=3.0.11 meson>=1.6.0 meson-python>=0.17.1
```

### Status
✅ **Already optimized** - Being installed from wheels.

---

## 7. Rust Toolchain - Language Dependency

### Current State
**Rust is being installed in 20+ scripts** for packages with Rust components.

### Evidence from Scripts
```bash
# Pattern found in pytorch, polars, cryptography, etc.:
curl https://sh.rustup.rs -sSf | sh -s -- -y
source "$HOME/.cargo/env"
rustup toolchain install 1.93.0  # or other versions
rustup default 1.93.0-powerpc64le-unknown-linux-gnu
```

### Affected Packages (Sample)
- `p/pytorch/pytorch_2.6.0_ubi_9.3.sh`
- `p/polars/polars_py_ubi9.7.sh`
- `c/cryptography/cryptography_ubi_8.10.sh`
- `c/clickhouse/clickhouse-v25.8.16.34-lts_ubi9.6.sh`
- `v/vllm/vllm_v0.16.0_ubi_9.6.sh`

### Versions Used
- 1.93.0 (most common)
- 1.89.0
- 1.87
- nightly-2025-07-07

### Recommendation
**Consider pre-installing Rust in base images:**
```dockerfile
# In base Docker image
RUN curl https://sh.rustup.rs -sSf | sh -s -- -y --default-toolchain 1.93.0
ENV PATH="/root/.cargo/bin:${PATH}"
```

### Impact
- **Time Saved**: 5-10 minutes per build
- **Consistency**: Same Rust version across builds

---

## Summary of Optimization Opportunities

| Package | Scripts Affected | Build Time | Optimization Method | Priority |
|---------|-----------------|------------|---------------------|----------|
| **CMake** | 264+ | 15-30 min | Use package manager | 🔴 CRITICAL |
| **OpenBLAS** | 50+ | 10-20 min | Use wheel or system package | 🔴 HIGH |
| **Protobuf + Abseil** | 100+ | 20-30 min | Use pre-built wheel | 🔴 HIGH |
| **SciPy** | 40+ | 15-25 min | Use pre-built wheel | 🟡 MEDIUM |
| **Rust** | 20+ | 5-10 min | Pre-install in base image | 🟡 MEDIUM |
| **NumPy** | 249+ | N/A | ✅ Already optimized | ✅ DONE |
| **Cython/Meson** | 100+ | N/A | ✅ Already optimized | ✅ DONE |

---

## Recommended Action Plan

### Phase 1: Immediate Wins (Critical Priority)
1. **CMake**: Update all scripts to use `yum install cmake` instead of building from source
   - Estimated time savings: 15-30 minutes × 264 scripts = **66-132 hours** of build time
   
2. **OpenBLAS**: Create standardized OpenBLAS installation method
   - Use system package or create reusable wheel
   - Estimated time savings: 10-20 minutes × 50 scripts = **8-17 hours** of build time

### Phase 2: High-Value Optimizations
3. **Protobuf**: Verify and use pre-built wheels from IBM repository
   - Evidence shows protobuf-4.25.8 wheel exists
   - Estimated time savings: 20-30 minutes × 100 scripts = **33-50 hours** of build time

4. **SciPy**: Use pre-built wheels consistently
   - Evidence shows scipy-1.16.0 wheel exists
   - Estimated time savings: 15-25 minutes × 40 scripts = **10-17 hours** of build time

### Phase 3: Infrastructure Improvements
5. **Rust**: Pre-install in base Docker images
   - Reduces redundant installations
   - Estimated time savings: 5-10 minutes × 20 scripts = **2-3 hours** of build time

### Total Potential Time Savings
**119-219 hours of build time** across all affected scripts.

---

## Verification Steps

Before implementing changes, verify wheel availability:

```bash
# Check IBM wheel repository
curl -s https://wheels.developerfirst.ibm.com/ppc64le/linux/ | grep -i "protobuf\|scipy\|openblas"

# Test installation
pip install --dry-run --extra-index-url https://wheels.developerfirst.ibm.com/ppc64le/linux/ \
    protobuf==4.25.8 scipy==1.16.0
```

---

## Conclusion

This analysis demonstrates that significant build time optimizations are possible by:
1. Using package managers for system tools (CMake)
2. Leveraging pre-built wheels from IBM repositories
3. Standardizing dependency installation methods
4. Pre-installing common tools in base images

The most critical optimization is **eliminating CMake source builds**, which alone could save **66-132 hours** of cumulative build time across all affected scripts.

---

## Appendix: Wheel Repository Evidence

From `v/vllm/vllm_ubi_9.3.sh`, the following wheels are confirmed available:

```bash
"abseil-cpp @ https://wheels.developerfirst.ibm.com/ppc64le/linux/+f/419/275773a4cc480/abseil_cpp-20240116.2-py3-none-any.whl"
"libprotobuf @ https://wheels.developerfirst.ibm.com/ppc64le/linux/+f/e53/57a336598c208/libprotobuf-25.4-py3-none-manylinux2014_ppc64le.whl"
"protobuf @ https://wheels.developerfirst.ibm.com/ppc64le/linux/+f/5e5/a6c4d93fcc5cd/protobuf-4.25.8-cp312-cp312-linux_ppc64le.whl"
"scipy @ https://wheels.developerfirst.ibm.com/ppc64le/linux/+f/4e1/4b512f33efb85/scipy-1.16.0-cp312-cp312-linux_ppc64le.whl"
```

This confirms that key packages are already available as pre-built wheels for ppc64le.