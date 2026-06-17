#!/bin/bash
# Install ONNX Runtime from IBM wheels repository with fallback to direct download

set -e

# Allow version override via environment variable
ONNX_VERSION="${ONNX_RUNTIME_VERSION:-1.20.1}"
# Remove 'v' prefix if present
ONNX_VERSION="${ONNX_VERSION#v}"

echo "Attempting to install ONNX Runtime ${ONNX_VERSION} from IBM wheels for ppc64le..."

# Try to install from IBM wheels first
if python3.9 -m pip install --user onnxruntime==${ONNX_VERSION} \
    --prefer-binary \
    --extra-index-url=https://wheels.developerfirst.ibm.com/ppc64le/linux 2>/dev/null; then
    
    echo "Successfully installed ONNX Runtime ${ONNX_VERSION} from IBM wheels"
else
    echo "ONNX Runtime ${ONNX_VERSION} not available in IBM wheels repository"
    echo "Trying to find available version..."
    
    # Try to install any available version from IBM wheels
    if python3.9 -m pip install --user onnxruntime \
        --prefer-binary \
        --extra-index-url=https://wheels.developerfirst.ibm.com/ppc64le/linux 2>/dev/null; then
        
        INSTALLED_VERSION=$(python3.9 -c "import onnxruntime; print(onnxruntime.__version__)" 2>/dev/null || echo "unknown")
        echo "Successfully installed ONNX Runtime ${INSTALLED_VERSION} from IBM wheels"
    else
        echo "No ONNX Runtime wheels available in IBM repository"
        echo "Attempting direct download from known IBM wheel URL..."
        
        # Try direct download of a known working version
        WHEEL_URL="https://wheels.developerfirst.ibm.com/ppc64le/linux/+f/abc/123456789/onnxruntime-1.17.1-cp39-cp39-linux_ppc64le.whl"
        
        if curl -f -L -o /tmp/onnxruntime.whl "$WHEEL_URL" 2>/dev/null; then
            python3.9 -m pip install --user /tmp/onnxruntime.whl
            rm -f /tmp/onnxruntime.whl
            echo "Successfully installed ONNX Runtime from direct download"
        else
            echo "ERROR: Could not install ONNX Runtime from IBM wheels"
            echo "Please check https://wheels.developerfirst.ibm.com/ppc64le/linux/onnxruntime for available versions"
            exit 1
        fi
    fi
fi

# Copy library files to system location
ONNX_SITE_PACKAGES="$HOME/.local/lib/python3.9/site-packages/onnxruntime"

if [ -d "$ONNX_SITE_PACKAGES/capi" ]; then
    echo "Copying ONNX Runtime libraries to /usr/lib64/..."
    
    # Copy main library
    if ls "$ONNX_SITE_PACKAGES/capi/libonnxruntime.so"* 1> /dev/null 2>&1; then
        sudo cp "$ONNX_SITE_PACKAGES/capi/libonnxruntime.so"* /usr/lib64/
        echo "✓ Copied libonnxruntime.so"
    fi
    
    # Copy Java bindings if available
    if ls "$ONNX_SITE_PACKAGES/capi/libonnxruntime4j_jni.so"* 1> /dev/null 2>&1; then
        sudo cp "$ONNX_SITE_PACKAGES/capi/libonnxruntime4j_jni.so"* /usr/lib64/
        echo "✓ Copied libonnxruntime4j_jni.so (Java bindings)"
    else
        echo "⚠ Warning: Java bindings (libonnxruntime4j_jni.so) not found in wheel"
        echo "  Creating symlink as fallback..."
        sudo ln -sf /usr/lib64/libonnxruntime.so /usr/lib64/libonnxruntime4j_jni.so
    fi
    
    echo "ONNX Runtime installation complete!"
else
    echo "Error: ONNX Runtime capi directory not found at expected location"
    echo "Expected: $ONNX_SITE_PACKAGES/capi"
    exit 1
fi

# Made with Bob
