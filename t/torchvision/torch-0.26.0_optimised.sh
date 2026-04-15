#!/bin/bash -e
#
# -----------------------------------------------------------------------------
#
# Package           : vision
# Version           : v0.26.0
# Source repo       : https://github.com/pytorch/vision.git
# Tested on         : UBI:9.6
# Language          : Python
# Ci-Check      : True
# Script License    : Apache License, Version 2.0
# Maintainer        : Ira <ira.pandey1@ibm.com>
#
# Disclaimer        : This script has been tested in root mode on given
# ==========          platform using the mentioned version of the package.
#                     It may not work as expected with newer versions of the
#                     package and/or distribution. In such case, please
#                     contact "Maintainer" of this script.
#
# ----------------------------------------------------------------------------

set -euxo pipefail

PACKAGE_NAME=vision
PACKAGE_VERSION=${1:-v0.26.0}
PACKAGE_URL=https://github.com/pytorch/vision.git
OS_NAME=$(cat /etc/os-release | grep ^PRETTY_NAME | cut -d= -f2)
MAX_JOBS=${MAX_JOBS:-$(nproc)}
VERSION=${PACKAGE_VERSION#v}
PYTHON_VERSION=${2:-3.12}
PYTORCH_VERSION=${3:-v2.11.0}

CURRENT_DIR=$(pwd)

yum install -y git make wget python$PYTHON_VERSION python$PYTHON_VERSION-devel python$PYTHON_VERSION-pip pkgconfig atlas libjpeg-devel openblas-devel
yum install gcc-toolset-13 -y
yum install -y make libtool  xz zlib-devel openssl-devel bzip2-devel libffi-devel libevent-devel  patch ninja-build gcc-toolset-13  pkg-config  gmp-devel  freetype-devel

ln -sf /usr/bin/pip$PYTHON_VERSION /usr/bin/pip3 && ln -sf /usr/bin/python$PYTHON_VERSION /usr/bin/python3 && ln -sf /usr/bin/pip$PYTHON_VERSION /usr/bin/pip && ln -sf /usr/bin/python$PYTHON_VERSION /usr/bin/python

export PYTHON_SITE_PACKAGES=$(python - <<'EOF'
import sysconfig, os

venv = os.environ.get("VIRTUAL_ENV")
paths = sysconfig.get_paths()

if venv:
    # Prefer venv path
    print(paths["platlib"])
else:
    # System python
    print(paths["platlib"])
EOF
)

dnf install -y gcc-toolset-13-libatomic-devel

export PATH="$PATH:/opt/rh/gcc-toolset-13/root/usr/bin"
export LD_LIBRARY_PATH="/opt/rh/gcc-toolset-13/root/usr/lib64:/opt/rh/gcc-toolset-13/root/usr/lib:${LD_LIBRARY_PATH:-}"

echo "------------Installing cmake---------------------------"

echo "Installing cmake..."
pip install cmake
cd $CURRENT_DIR

echo "---------------------openblas installing---------------------"

#install openblas
python3 -m pip install openblas==0.3.29+ppc64le1 \
  --prefer-binary \
  --extra-index-url=https://wheels.developerfirst.ibm.com/ppc64le/linux
cd $CURRENT_DIR

echo "--------------------scipy installing-------------------------------"

# python3 -m pip install scipy==1.15.2+ppc64le1 \
#   --prefer-binary \
#   --extra-index-url=https://wheels.developerfirst.ibm.com/ppc64le/linux

#Building scipy
python3 -m pip install beniget==0.4.2.post1 Cython gast==0.6.0 meson==1.6.0 meson-python==0.17.1 numpy==2.0.2 packaging pybind11 pyproject-metadata pythran==0.17.0 setuptools==75.3.0 pooch pytest build wheel hypothesis ninja patchelf
git clone https://github.com/scipy/scipy
cd scipy/
git checkout v1.15.2
git submodule update --init
echo "instaling scipy......."
python3 -m pip install .
cd $CURRENT_DIR

echo "--------------------abseil-cpp installing-------------------------------"

#installing abseil-cpp
python3 -m pip install abseil-cpp==20240116.2+ppc64le1 \
  --prefer-binary \
  --extra-index-url=https://wheels.developerfirst.ibm.com/ppc64le/linux

# Ensure local abseil-cpp source exists for protobuf third_party injection.
if [ ! -d "$CURRENT_DIR/abseil-cpp" ]; then
  git clone --depth 1 --branch 20240116.2 https://github.com/abseil/abseil-cpp.git "$CURRENT_DIR/abseil-cpp"
fi
#building libprotobuf
export C_COMPILER=$(which gcc)
export CXX_COMPILER=$(which g++)

echo "----------------protobuf installing-------------------"
git clone https://github.com/protocolbuffers/protobuf
cd protobuf
git checkout v4.25.8

LIBPROTO_DIR=$(pwd)
mkdir -p $LIBPROTO_DIR/local/libprotobuf
LIBPROTO_INSTALL=$LIBPROTO_DIR/local/libprotobuf

git submodule update --init --recursive
rm -rf ./third_party/googletest
rm -rf ./third_party/abseil-cpp

cp -r $CURRENT_DIR/abseil-cpp ./third_party/

mkdir build
cd build

cmake -G "Ninja" \
   ${CMAKE_ARGS:-} \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_CXX_STANDARD=17 \
    -DCMAKE_C_COMPILER=$C_COMPILER \
    -DCMAKE_CXX_COMPILER=$CXX_COMPILER \
    -DCMAKE_INSTALL_PREFIX=$LIBPROTO_INSTALL \
    -Dprotobuf_BUILD_TESTS=OFF \
    -Dprotobuf_BUILD_LIBUPB=OFF \
    -Dprotobuf_BUILD_SHARED_LIBS=ON \
    -Dprotobuf_ABSL_PROVIDER="module" \
    -Dprotobuf_JSONCPP_PROVIDER="package" \
    -Dprotobuf_USE_EXTERNAL_GTEST=OFF \
    ..
echo "building libprotobuf...."
cmake --build . --verbose
echo "Installing libprotobuf...."
cmake --install .

cd ..

#Build protobuf
export PROTOC=$LIBPROTO_DIR/build/protoc
export LD_LIBRARY_PATH="$CURRENT_DIR/abseil-cpp/abseilcpp/lib:$(pwd)/build:${LD_LIBRARY_PATH:-}"
export LIBRARY_PATH="$(pwd)/build:${LIBRARY_PATH:-}"
export PROTOCOL_BUFFERS_PYTHON_IMPLEMENTATION=cpp
export PROTOCOL_BUFFERS_PYTHON_IMPLEMENTATION_VERSION=2

#Apply patch
wget https://raw.githubusercontent.com/ppc64le/build-scripts/refs/heads/master/p/protobuf/set_cpp_to_17_v4.25.3.patch
git apply set_cpp_to_17_v4.25.3.patch

echo "Installing protobuf...."
cd python
python3 -m pip install . --no-build-isolation
cd $CURRENT_DIR

echo "------------ libprotobuf,protobuf installed--------------"

echo "----Installing rust------"
curl https://sh.rustup.rs -sSf | sh -s -- -y
source "$HOME/.cargo/env"

echo "--------------------------Installing pytorch------------------------------------------"
git clone https://github.com/pytorch/pytorch.git
cd pytorch
git checkout $PYTORCH_VERSION
git submodule sync
git submodule update --init --recursive

ver=${PYTORCH_VERSION#v}

PATCH_URL="https://raw.githubusercontent.com/ppc64le/build-scripts/refs/heads/master/p/pytorch/pytorch_${PYTORCH_VERSION}.patch"
PATCH_FILE="pytorch_${PYTORCH_VERSION}.patch"

# Using patch file v2.9.1 for PACKAGE_VERSION >= v2.9.1 (eg: v2.10.0, v2.11.0).
# If a new patch is added eg: v2.9.1 patch is not working with v2.15.1,
# please add a similar condition below for v2.15.1.
if [[ "$(printf '%s\n' "$ver" "2.9.1" | sort -V | tail -n1)" == "$ver" ]]; then
    PATCH_URL="https://raw.githubusercontent.com/ppc64le/build-scripts/refs/heads/master/p/pytorch/pytorch_v2.9.1.patch"
    PATCH_FILE="pytorch_v2.9.1.patch"
fi
wget -q --spider "$PATCH_URL" && wget -q "$PATCH_URL" && git apply "$PATCH_FILE"

ARCH=`uname -p`
BUILD_NUM="1"
export OPENBLAS_INCLUDE="/usr/include/openblas"
OPENBLAS_LIB_DIR="$(pkg-config --variable=libdir openblas 2>/dev/null || echo /usr/lib64)"
export LD_LIBRARY_PATH="${OPENBLAS_LIB_DIR}:${LD_LIBRARY_PATH:-}"
export OpenBLAS_HOME="/usr/include/openblas"
export ppc_arch="p9"
export build_type="cpu"
export cpu_opt_arch="power9"
export cpu_opt_tune="power10"
export CPU_COUNT=$(nproc --all)
export CXXFLAGS="${CXXFLAGS:-} -D__STDC_FORMAT_MACROS"
export LDFLAGS="$(echo "${LDFLAGS:-}" | sed -e 's/-Wl\,--as-needed//')"
if [[ -n "${VIRTUAL_ENV:-}" ]]; then
  export LDFLAGS="${LDFLAGS:-} -Wl,-rpath-link,${VIRTUAL_ENV}/lib"
fi
export CXXFLAGS="${CXXFLAGS:-} -fplt"
export CFLAGS="${CFLAGS:-} -fplt"
export BLAS=OpenBLAS
export USE_FBGEMM=0
export USE_SYSTEM_NCCL=1
export USE_MKLDNN=0
export USE_NNPACK=0
export USE_QNNPACK=0
export USE_XNNPACK=0
export USE_PYTORCH_QNNPACK=0
export TH_BINARY_BUILD=1
export USE_LMDB=1
export USE_LEVELDB=1
export USE_NINJA=0
export USE_MPI=0
export USE_OPENMP=1
export USE_TBB=0
export BUILD_CUSTOM_PROTOBUF=OFF
export BUILD_CAFFE2=1
export PYTORCH_BUILD_VERSION=${PYTORCH_VERSION#v}
export PYTORCH_BUILD_NUMBER=${BUILD_NUM}
export USE_CUDA=0
export USE_CUDNN=0
export USE_TENSORRT=0
export Protobuf_INCLUDE_DIR=${LIBPROTO_INSTALL}/include
export Protobuf_LIBRARIES=${LIBPROTO_INSTALL}/lib64
export Protobuf_LIBRARY=${LIBPROTO_INSTALL}/lib64/libprotobuf.so
export Protobuf_LITE_LIBRARY=${LIBPROTO_INSTALL}/lib64/libprotobuf-lite.so
export Protobuf_PROTOC_EXECUTABLE=${LIBPROTO_INSTALL}/bin/protoc
export LD_LIBRARY_PATH="$CURRENT_DIR/pytorch/torch/lib64:${LD_LIBRARY_PATH}"
export LD_LIBRARY_PATH="$CURRENT_DIR/pytorch/build/lib:${LD_LIBRARY_PATH}"
export PATH="$CURRENT_DIR/protobuf/local/libprotobuf/bin:${PATH}"
export LD_LIBRARY_PATH="$CURRENT_DIR/protobuf/local/libprotobuf/lib64:${LD_LIBRARY_PATH}"
export LD_LIBRARY_PATH="$CURRENT_DIR/protobuf/third_party/abseil-cpp/local/abseilcpp/lib:${LD_LIBRARY_PATH}"
# Build python requirements with system linker path to avoid gcc-toolset ld/libctf mismatch
# seen while compiling psutil/lintrunner wheels on UBI.
SYSTEM_PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
FILTERED_REQ_FILE="$CURRENT_DIR/pytorch/requirements-no-lint.txt"
awk 'tolower($0) !~ /^psutil([<=> ].*)?$/ && tolower($0) !~ /^lintrunner([<=> ].*)?$/' requirements.txt > "$FILTERED_REQ_FILE"
PATH="$SYSTEM_PATH" CC=/usr/bin/gcc CXX=/usr/bin/g++ LDSHARED="/usr/bin/gcc -shared" python3 -m pip install -r "$FILTERED_REQ_FILE"

echo "----------Installing pytorch------------"
PATH="$SYSTEM_PATH" CC=/usr/bin/gcc CXX=/usr/bin/g++ LD=/usr/bin/ld LDSHARED="/usr/bin/gcc -shared" CMAKE_C_COMPILER=/usr/bin/gcc CMAKE_CXX_COMPILER=/usr/bin/g++ MAX_JOBS=$(nproc) python3 setup.py install
PATH="$SYSTEM_PATH" CC=/usr/bin/gcc CXX=/usr/bin/g++ LD=/usr/bin/ld LDSHARED="/usr/bin/gcc -shared" CMAKE_C_COMPILER=/usr/bin/gcc CMAKE_CXX_COMPILER=/usr/bin/g++ MAX_JOBS=$(nproc) python3 setup.py bdist_wheel
cd $CURRENT_DIR

echo "--------------------------------- Installing Opus ---------------------------------"

# Installing opus
python3 -m pip install opus==1.3.1+ppc64le1 \
  --prefer-binary \
  --extra-index-url=https://wheels.developerfirst.ibm.com/ppc64le/linux


echo "--------------------------------- Opus Installed Successfully ---------------------------------"

cd $CURRENT_DIR

echo "--------------------------------- Installing libvpx ---------------------------------"

python3 -m pip install libvpx==1.13.1+ppc64le1 \
  --prefer-binary \
  --extra-index-url=https://wheels.developerfirst.ibm.com/ppc64le/linux

echo "--------------------------------- libvpx Installed Successfully ---------------------------------"

cd $CURRENT_DIR

echo "--------------------------------- Installing lame ---------------------------------"

python3 -m pip install lame==3.100+ppc64le1 \
  --prefer-binary \
  --extra-index-url=https://wheels.developerfirst.ibm.com/ppc64le/linux

echo "--------------------------------- lame Installed Successfully ---------------------------------"

cd $CURRENT_DIR

echo "---------------------------Installing FFmpeg------------------"
python3 -m pip install ffmpeg==7.1+ppc64le1 \
  --prefer-binary \
  --extra-index-url=https://wheels.developerfirst.ibm.com/ppc64le/linux



echo "--------------------------------- ffmpeg Installed successfully ---------------------------------"

cd $CURRENT_DIR

echo "--------------------------Installing pillow-----------------------------"
git clone https://github.com/python-pillow/Pillow
cd Pillow
git checkout 11.1.0

yum install -y libjpeg-turbo-devel libjpeg-devel
git submodule update --init

python3 -m pip install .
cd $CURRENT_DIR

echo "--------------------Installing pyav----------------------------"
git clone https://github.com/PyAV-Org/PyAV
cd PyAV

# This command prints both versions, one per line, then sorts them using version-aware sort (-V)
# The smallest version will appear first
# If the smallest version is not 0.22.0, then VERSION must be less than 0.22.0

if [ "$(printf '%s\n' "$VERSION" "0.22.0" | sort -V | head -n1)" != "0.22.0" ]; then
    # VERSION is less than 0.22.0
    git checkout v13.1.0
else
    # VERSION is greater than or equal to 0.22.0
    # This PyAV version must match the runtime PyAV version.
    git checkout v14.4.0
    sed -i 's/license = "BSD-3-Clause"/license = {text = "BSD-3-Clause"}/' pyproject.toml
fi

git submodule update --init

export CFLAGS="${CFLAGS:-} -I/install-deps/ffmpeg/include"
export LDFLAGS="${LDFLAGS:-} -L/install-deps/ffmpeg/lib"

python3 setup.py build_ext --inplace
cd $CURRENT_DIR

echo "------------------Building torchvision------------------------"
git clone $PACKAGE_URL
cd $PACKAGE_NAME
git checkout $PACKAGE_VERSION

# Below patch is needed to exclude the models that come under SWAG license (CC-BY-NC-4.0)
# Using patch file v0.25.0 for PACKAGE_VERSION >= v0.25.0 (eg: v0.26.0).
wget https://raw.githubusercontent.com/ppc64le/build-scripts/refs/heads/master/t/torchvision/0001-Exclude-source-that-has-commercial-license_v0.25.0.patch
git apply 0001-Exclude-source-that-has-commercial-license_v0.25.0.patch


sed -i '/elif sha != "Unknown":/,+1d' setup.py

if ! python3 setup.py build; then
    echo "------------------$PACKAGE_NAME:install_fails-------------------------------------"
    echo "$PACKAGE_URL $PACKAGE_NAME"
    echo "$PACKAGE_NAME  |  $PACKAGE_URL | $PACKAGE_VERSION | $OS_NAME | GitHub | Fail |  Install_Fails"
    exit 1
fi

cd build
export CMAKE_PREFIX_PATH=$CURRENT_DIR/pytorch/torch/share/cmake/Torch:$LIBPROTO_INSTALL
cmake ..
make install
cp libtorchvision.so $CURRENT_DIR/vision/torchvision/libtorchvision.so
cp libtorchvision.so $PYTHON_SITE_PACKAGES/torch/share/cmake/Torch
cp libtorchvision.so /usr/local/lib64
cd $CURRENT_DIR/vision

export LD_LIBRARY_PATH="${CURRENT_DIR}/pytorch/build/lib/:${LD_LIBRARY_PATH:-}"
export LD_LIBRARY_PATH="${CURRENT_DIR}/protobuf/local/libprotobuf/lib64/:${LD_LIBRARY_PATH:-}"

python3 setup.py bdist_wheel --dist-dir $CURRENT_DIR

cd $CURRENT_DIR

python3 -m pip install ./torchvision*.whl

python3 -m pip install pytest pytest-xdist

# Run tests
if ! pytest $PACKAGE_NAME/test/common_extended_utils.py $PACKAGE_NAME/test/common_utils.py $PACKAGE_NAME/test/smoke_test.py $PACKAGE_NAME/test/test_architecture_ops.py ; then
    echo "------------------$PACKAGE_NAME:install_success_but_test_fails---------------------"
    echo "$PACKAGE_URL $PACKAGE_NAME"
    echo "$PACKAGE_NAME  |  $PACKAGE_URL | $PACKAGE_VERSION | $OS_NAME | GitHub | Fail |  Install_success_but_test_Fails"
    exit 2
else
    echo "------------------$PACKAGE_NAME:install_&_test_both_success-------------------------"
    echo "$PACKAGE_URL $PACKAGE_NAME"
    echo "$PACKAGE_NAME  |  $PACKAGE_URL | $PACKAGE_VERSION | $OS_NAME | GitHub  | Pass |  Both_Install_and_Test_Success"
    exit 0
fi

