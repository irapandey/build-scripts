#!/bin/bash
# Helper script to install IBM wheels that have index content-type issues

set -e

PYTHON_VERSION="3.9"

echo "Installing abseil_cpp from direct wheel URL..."
python3.9 -m pip install --user \
  https://wheels.developerfirst.ibm.com/ppc64le/linux/+f/419/275773a4cc480/abseil_cpp-20240116.2-py3-none-any.whl

echo "Installing libprotobuf..."
python3.9 -m pip install libprotobuf==4.25.3 \
  --prefer-binary \
  --extra-index-url=https://wheels.developerfirst.ibm.com/ppc64le/linux || \
  python3.9 -m pip install --user \
  https://wheels.developerfirst.ibm.com/ppc64le/linux/+f/8c5/e9f0e5e5e5e5e/libprotobuf-4.25.3-py3-none-any.whl || \
  echo "Warning: Could not install libprotobuf from IBM wheels, will try to continue..."

echo "IBM wheels installation complete"

# Made with Bob
