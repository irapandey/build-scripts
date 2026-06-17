# How to Build DJL v0.33.0 with PyTorch v2.1.2

This guide provides step-by-step instructions for building DJL (Deep Java Library) with PyTorch support on ppc64le architecture.

## Prerequisites

### System Requirements
- **OS**: UBI 9.7 or RHEL 9.x
- **Architecture**: ppc64le (Power)
- **RAM**: 8GB minimum, 16GB recommended
- **Disk Space**: 20GB free space
- **Time**: 30-45 minutes for first build

### Required Packages
```bash
sudo yum install -y \
  java-21-openjdk-devel \
  wget git unzip make cmake \
  gcc gcc-c++ gcc-gfortran \
  perl python3.9-devel python3.9-pip \
  zlib-devel openssl-devel libffi-devel \
  openblas-devel
```

## Method 1: Using the Standalone Script (Recommended)

### Step 1: Navigate to the Script Directory
```bash
cd /path/to/build-scripts/o/opensearch-project-ml-commons
```

### Step 2: Run the DJL Build Script
```bash
bash build_djl_pytorch_v2.1.2.sh
```

### Step 3: Wait for Build to Complete
The script will:
1. Install Rust (required for tokenizers)
2. Install PyTorch 2.1.2 from IBM wheels
3. Install dependencies (abseil_cpp, libprotobuf)
4. Clone and build DJL v0.33.0
5. Publish to Maven local repository
6. Create installation at `~/.local/djl-pytorch-2.1.2/`

### Step 4: Verify Installation
```bash
# Check if DJL was installed
ls -la ~/.local/djl-pytorch-2.1.2/

# Check Maven artifacts
ls -la ~/.m2/repository/ai/djl/

# Source the environment
source ~/.local/djl-pytorch-2.1.2/setup-env.sh
```

## Method 2: Using Docker

### Step 1: Build Docker Image
```bash
cd /path/to/build-scripts
docker build -t djl-builder -f o/opensearch-project-ml-commons/Dockerfile .
```

### Step 2: Run DJL Build in Container
```bash
# Create output directory
mkdir -p djl-output

# Run the build
docker run -it \
  -v $(pwd)/djl-output:/output \
  --entrypoint /bin/bash \
  djl-builder

# Inside container, run:
bash o/opensearch-project-ml-commons/build_djl_pytorch_v2.1.2.sh
```

### Step 3: Extract Built Artifacts
The DJL artifacts will be in the container at:
- `~/.local/djl-pytorch-2.1.2/` - Installation directory
- `~/.m2/repository/ai/djl/` - Maven artifacts

## Method 3: Manual Build (Advanced)

If you need to customize the build process:

### Step 1: Set Up Environment
```bash
export JAVA_HOME=$(compgen -G '/usr/lib/jvm/java-21-openjdk-*' | head -n 1)
export PATH=${JAVA_HOME}/bin:$PATH
export DJL_VERSION="v0.33.0"
export PYTORCH_VERSION="2.1.2"
export PYTHON_VERSION="3.9"
export BUILD_HOME="$(pwd)/djl_build"
export DJL_HOME="$HOME/.djl.ai"
```

### Step 2: Install Rust
```bash
curl https://sh.rustup.rs -sSf | sh -s -- -y
source $HOME/.cargo/env
rustup install 1.87
rustup default 1.87
```

### Step 3: Install Python Dependencies
```bash
python3.9 -m pip install --user packaging "numpy<2.0" wheel setuptools

# Install PyTorch 2.1.2
python3.9 -m pip install --user torch==2.1.2 \
  --prefer-binary \
  --extra-index-url=https://wheels.developerfirst.ibm.com/ppc64le/linux-1.0.0

# Install abseil_cpp
python3.9 -m pip install --user abseil_cpp==20240116.2 \
  --prefer-binary \
  --extra-index-url=https://wheels.developerfirst.ibm.com/ppc64le/linux

# Install libprotobuf
python3.9 -m pip install --user libprotobuf==4.25.3 \
  --prefer-binary \
  --extra-index-url=https://wheels.developerfirst.ibm.com/ppc64le/linux
```

### Step 4: Clone and Prepare DJL
```bash
mkdir -p $BUILD_HOME
cd $BUILD_HOME
git clone https://github.com/deepjavalibrary/djl
cd djl/
git checkout $DJL_VERSION

# Apply patch if available
if [ -f "/path/to/djl_v0.33.0.patch" ]; then
    git apply /path/to/djl_v0.33.0.patch
fi
```

### Step 5: Set Up libtorch Directory
```bash
# Create libtorch directory structure
mkdir -p $BUILD_HOME/djl/engines/pytorch/pytorch-native/libtorch

# Copy PyTorch components from Python installation
cp -r $HOME/.local/lib/python$PYTHON_VERSION/site-packages/torch/include \
    $BUILD_HOME/djl/engines/pytorch/pytorch-native/libtorch/

cp -r $HOME/.local/lib/python$PYTHON_VERSION/site-packages/torch/lib \
    $BUILD_HOME/djl/engines/pytorch/pytorch-native/libtorch/

cp -r $HOME/.local/lib/python$PYTHON_VERSION/site-packages/torch/share \
    $BUILD_HOME/djl/engines/pytorch/pytorch-native/libtorch/

# Copy abseil libraries
cp -r $HOME/.local/lib/python$PYTHON_VERSION/site-packages/abseilcpp/lib/* \
    $BUILD_HOME/djl/engines/pytorch/pytorch-native/libtorch/lib/
```

### Step 6: Set Up DJL Runtime Directory
```bash
mkdir -p $DJL_HOME/pytorch/${PYTORCH_VERSION}-cpu-linux-ppc64le/

# Copy PyTorch libraries
cp $HOME/.local/lib/python$PYTHON_VERSION/site-packages/torch/lib/* \
    $DJL_HOME/pytorch/${PYTORCH_VERSION}-cpu-linux-ppc64le/

# Copy additional dependencies
cp $HOME/.local/lib/python$PYTHON_VERSION/site-packages/libprotobuf/lib64/libprotobuf.so.25.3.0 \
    $DJL_HOME/pytorch/${PYTORCH_VERSION}-cpu-linux-ppc64le/

cp /usr/lib64/libopenblas.so.0 $DJL_HOME/pytorch/${PYTORCH_VERSION}-cpu-linux-ppc64le/
cp /usr/lib64/libgfortran.so.5 $DJL_HOME/pytorch/${PYTORCH_VERSION}-cpu-linux-ppc64le/
cp /usr/lib64/libquadmath.so.0 $DJL_HOME/pytorch/${PYTORCH_VERSION}-cpu-linux-ppc64le/

# Copy abseil libraries
cp -r $HOME/.local/lib/python$PYTHON_VERSION/site-packages/abseilcpp/lib/* \
    $DJL_HOME/pytorch/${PYTORCH_VERSION}-cpu-linux-ppc64le/

# Create versioned symlinks for abseil libraries
cd $DJL_HOME/pytorch/${PYTORCH_VERSION}-cpu-linux-ppc64le/
for f in libabsl_*.so; do 
    if [ -f "$f" ]; then
        ln -sf $f ${f}.2401.0.0
    fi
done
```

### Step 7: Build DJL Components
```bash
cd $BUILD_HOME/djl
export LD_LIBRARY_PATH=$DJL_HOME/pytorch/${PYTORCH_VERSION}-cpu-linux-ppc64le:$LD_LIBRARY_PATH

# Build PyTorch engine
./gradlew :engines:pytorch:pytorch-native:compileJNI

# Test PyTorch engine (optional, may have some failures)
./gradlew --no-daemon :engines:pytorch:pytorch-engine:test \
  -Dengine.pytorch.disable_native_extraction=true \
  -Djava.library.path=$DJL_HOME/pytorch/${PYTORCH_VERSION}-cpu-linux-ppc64le || \
  echo "Warning: Some tests failed, continuing..."

# Build tokenizers
./gradlew :extensions:tokenizers:compileJNI

# Test tokenizers (optional)
./gradlew --no-daemon :extensions:tokenizers:test \
  -Dengine.pytorch.disable_native_extraction=true \
  -Djava.library.path=$DJL_HOME/pytorch/${PYTORCH_VERSION}-cpu-linux-ppc64le \
  -Dai.djl.debug=true || \
  echo "Warning: Some tests failed, continuing..."

# Publish to Maven local
./gradlew -Prelease=true publishToMavenLocal

# Build BOM
cd bom
./gradlew build
./gradlew -Prelease=true publishToMavenLocal
```

## Verification

### Check Installation
```bash
# Verify DJL installation directory
ls -la ~/.local/djl-pytorch-2.1.2/
# Should show: lib/, maven/, setup-env.sh, README.md

# Verify Maven artifacts
ls -la ~/.m2/repository/ai/djl/
# Should show: api/, pytorch-engine/, pytorch-native-auto/, etc.

# Verify runtime libraries
ls -la ~/.djl.ai/pytorch/2.1.2-cpu-linux-ppc64le/
# Should show: libtorch*.so, libprotobuf.so.*, libopenblas.so.*, etc.
```

### Test DJL Installation
```bash
# Source the environment
source ~/.local/djl-pytorch-2.1.2/setup-env.sh

# Create a simple test
cat > TestDJL.java << 'EOF'
import ai.djl.engine.Engine;

public class TestDJL {
    public static void main(String[] args) {
        Engine engine = Engine.getEngine("PyTorch");
        System.out.println("DJL PyTorch Engine: " + engine.getVersion());
        System.out.println("Installation successful!");
    }
}
EOF

# Compile and run
javac -cp ~/.m2/repository/ai/djl/api/0.33.0/api-0.33.0.jar TestDJL.java
java -cp .:~/.m2/repository/ai/djl/api/0.33.0/api-0.33.0.jar:~/.m2/repository/ai/djl/pytorch/pytorch-engine/0.33.0/pytorch-engine-0.33.0.jar TestDJL
```

## Using Built DJL

### In Your Projects

#### Gradle
```groovy
repositories {
    mavenLocal()
    mavenCentral()
}

dependencies {
    implementation "ai.djl:api:0.33.0"
    implementation "ai.djl.pytorch:pytorch-engine:0.33.0"
    runtimeOnly "ai.djl.pytorch:pytorch-native-auto:0.33.0"
}
```

#### Maven
```xml
<dependencies>
    <dependency>
        <groupId>ai.djl</groupId>
        <artifactId>api</artifactId>
        <version>0.33.0</version>
    </dependency>
    <dependency>
        <groupId>ai.djl.pytorch</groupId>
        <artifactId>pytorch-engine</artifactId>
        <version>0.33.0</version>
    </dependency>
    <dependency>
        <groupId>ai.djl.pytorch</groupId>
        <artifactId>pytorch-native-auto</artifactId>
        <version>0.33.0</version>
        <scope>runtime</scope>
    </dependency>
</dependencies>
```

### Environment Setup
```bash
# Always source the environment before running DJL applications
source ~/.local/djl-pytorch-2.1.2/setup-env.sh

# Or set manually
export LD_LIBRARY_PATH=~/.local/djl-pytorch-2.1.2/lib:$LD_LIBRARY_PATH
export JAVA_OPTS="-Dorg.opensearch.djl.pytorch.path=~/.local/djl-pytorch-2.1.2/lib"
export JAVA_OPTS="$JAVA_OPTS -Djava.library.path=~/.local/djl-pytorch-2.1.2/lib"
```

## Troubleshooting

### CMake Cannot Find Torch
**Problem:** CMake error about missing TorchConfig.cmake

**Solution:** The build script copies the complete torch installation including the share/cmake directory. If you still see this error, verify:
```bash
ls -la ~/.local/lib/python3.9/site-packages/torch/share/cmake/Torch/
```

### Library Not Found
**Problem:** `java.lang.UnsatisfiedLinkError: no torch_jni in java.library.path`

**Solution:**
```bash
source ~/.local/djl-pytorch-2.1.2/setup-env.sh
```

### Build Fails with "Permission Denied"
**Problem:** Cannot write to directories

**Solution:**
```bash
# Ensure you're not running as root
whoami  # Should NOT be root

# Fix permissions if needed
sudo chown -R $USER:$USER ~/.local ~/.m2 ~/.djl.ai
```

### PyTorch Version Mismatch
**Problem:** Wrong PyTorch version installed

**Solution:**
```bash
# Uninstall existing PyTorch
python3.9 -m pip uninstall torch

# Install correct version
python3.9 -m pip install --user torch==2.1.2 \
  --prefer-binary \
  --extra-index-url=https://wheels.developerfirst.ibm.com/ppc64le/linux-1.0.0
```

## Next Steps

After building DJL, you can:
1. Use it to build ml-commons: `bash ml-commons_3.5.0.0_ubi9.7.sh --use-prebuilt-djl`
2. Develop your own DJL applications
3. Share the built artifacts with your team

## Support

For issues:
- Check the troubleshooting section above
- Review build logs in `$BUILD_HOME/djl/`
- Verify all dependencies are installed correctly
- Ensure you're using ppc64le architecture

## License

Apache License, Version 2.0 or later