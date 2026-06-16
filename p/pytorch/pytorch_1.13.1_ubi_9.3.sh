#!/bin/bash -e
 
# -----------------------------------------------------------------------------
#
# Package : pytorch
# Version : 1.13.1
# Source repo : https://github.com/pytorch/pytorch.git
# Tested on : UBI:9.3
# Language : Python
# Ci-Check : True
# Script License: Apache License, Version 2 or later
# Maintainer : Build Scripts Team
#
# Disclaimer: This script has been tested in root mode on the given
# platform using the mentioned version of the package.
# It may not work as expected with newer versions of the
# package and/or distribution. In such a case, please
# contact the "Maintainer" of this script.
#
# -----------------------------------------------------------------------------
 
# Exit immediately if a command exits with a non-zero status
set -e
 
# Variables
PACKAGE_NAME=pytorch
PACKAGE_VERSION=${1:-v1.13.1}
PACKAGE_URL=https://github.com/pytorch/pytorch.git
PACKAGE_DIR=pytorch
export PYTORCH_BUILD_VERSION="${PACKAGE_VERSION#v}"
export PYTORCH_BUILD_NUMBER=1
CURRENT_DIR="${PWD}"
 
# Install dependencies and tools
echo "Installing dependencies..."
yum install -y git wget openblas-devel cmake gcc-toolset-12-gcc gcc-toolset-12-gcc-c++ gcc-toolset-12-gcc-gfortran
yum install -y sudo zlib-devel ncurses make openssl-devel xz xz-devel libffi libffi-devel sqlite sqlite-devel sqlite-libs bzip2-devel
source /opt/rh/gcc-toolset-12/enable

# Set compiler paths to make use of right compiler
export CC=/opt/rh/gcc-toolset-12/root/usr/bin/gcc
export CXX=/opt/rh/gcc-toolset-12/root/usr/bin/g++
export LD=/opt/rh/gcc-toolset-12/root/usr/bin/ld
export CXXFLAGS="$CXXFLAGS -Wno-error=nonnull"
export CXXFLAGS="$CXXFLAGS -O2 -fPIC -Wno-error"
export CFLAGS="$CFLAGS -O2 -fPIC -Wno-error"
export NO_WERROR=1
export BUILD_TEST=0

# Build Python 3.9 from source if not available
if ! python3.9 --version &>/dev/null; then
    echo "Building Python 3.9 from source..."
    wget https://www.python.org/ftp/python/3.9.21/Python-3.9.21.tgz
    tar xf Python-3.9.21.tgz
    cd Python-3.9.21
    ./configure --prefix=/usr/local --enable-optimizations --enable-shared
    make -j$(nproc)
    make altinstall
    echo "Python 3.9 installed"
    cd ..
    rm -rf Python-3.9.21 Python-3.9.21.tgz
    
    # Update library path
    export LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH
    echo "/usr/local/lib" > /etc/ld.so.conf.d/python3.9.conf
    ldconfig
fi

echo "Installing required Python packages..."
python3.9 -m pip install --upgrade pip
python3.9 -m pip install wheel ninja build pytest typing-extensions

# Install numpy and scipy using pre-built wheels to avoid compilation issues
echo "Installing numpy and scipy for PyTorch 1.13.1"
python3.9 -m pip install "numpy==1.23.5"
python3.9 -m pip install "scipy==1.9.3" || python3.9 -m pip install "scipy==1.10.1"
 
# Check if Rust is installed
if ! command -v rustc &> /dev/null; then
    echo "Rust not found. Installing Rust..."
    curl https://sh.rustup.rs -sSf | sh -s -- -y
    source "$HOME/.cargo/env"
else
    echo "Rust is already installed."
fi
 
# Clone repository
echo "Cloning PyTorch repository..."
git clone $PACKAGE_URL
cd $PACKAGE_NAME
 
echo "Checking out version $PACKAGE_VERSION..."
git checkout $PACKAGE_VERSION
 
echo "Syncing and updating submodules..."
git submodule sync
git submodule update --init --recursive
 
echo "Installing package dependencies..."
python3.9 -m pip install -r requirements.txt
 
# Build and install the package
echo "Starting PyTorch build and installation..."
if ! (MAX_JOBS=$(nproc) python3.9 setup.py install); then
    echo "------------------$PACKAGE_NAME:install_fails-------------------------------------"
    echo "$PACKAGE_URL $PACKAGE_NAME"
    echo "$PACKAGE_NAME | $PACKAGE_URL | $PACKAGE_VERSION | $OS_NAME | GitHub | Fail | Install_Fails"
    exit 1
fi
 
echo "Building wheel file..."
python3.9 setup.py bdist_wheel --dist-dir="$CURRENT_DIR/"

# Create artifacts directory and copy wheel
mkdir -p "$CURRENT_DIR/artifacts"
if ls "$CURRENT_DIR"/*.whl 1> /dev/null 2>&1; then
    cp "$CURRENT_DIR"/*.whl "$CURRENT_DIR/artifacts/"
    echo "Wheel file copied to artifacts directory"
fi
 
cd ..
 
# Basic sanity test (subset)
echo "Running basic sanity test..."
if ! python3.9 -c "import torch; print(f'PyTorch version: {torch.__version__}')"; then
    echo "------------------$PACKAGE_NAME:install_success_but_test_fails---------------------"
    echo "$PACKAGE_URL $PACKAGE_NAME"
    echo "$PACKAGE_NAME | $PACKAGE_URL | $PACKAGE_VERSION | $OS_NAME | GitHub | Fail | Install_success_but_Test_Fails"
    exit 2
else
    echo "------------------$PACKAGE_NAME:install_&_test_both_success------------------------"
    echo "$PACKAGE_URL $PACKAGE_NAME"
    echo "$PACKAGE_NAME | $PACKAGE_URL | $PACKAGE_VERSION | $OS_NAME | GitHub | Pass | Both_Install_and_Test_Success"
    exit 0
fi

# Made with Bob
