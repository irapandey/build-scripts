FROM registry.access.redhat.com/ubi9/ubi:9.7

# Set up build environment
ENV BUILD_HOME=/home/tester/build_workspace
ENV SCRIPT_PATH=/home/tester/build-scripts/o/opensearch-project-ml-commons
ENV DJL_HOME=/home/tester/.djl.ai
ENV DJL_INSTALL_PREFIX=/home/tester/.local/djl-pytorch-2.1.2

# Install git and sudo as root
RUN yum install -y git sudo && yum clean all

# Create test_user with sudo privileges
RUN useradd -m -s /bin/bash test_user && \
    echo "test_user ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers && \
    mkdir -p /home/tester && \
    chown -R test_user:test_user /home/tester

# Switch to test_user
USER test_user
WORKDIR /home/tester

# Clone the repository and checkout the branch
RUN git clone https://github.com/irapandey/build-scripts.git && \
    cd build-scripts && \
    git checkout workflow-irapandey

# Set working directory to the script location
WORKDIR /home/tester/build-scripts

# Create artifacts directory
RUN mkdir -p /home/tester/artifacts

# Create a wrapper script for the build
RUN echo '#!/bin/bash' > /home/tester/run_build.sh && \
    echo 'set -e' >> /home/tester/run_build.sh && \
    echo 'cd /home/tester/build-scripts' >> /home/tester/run_build.sh && \
    echo '' >> /home/tester/run_build.sh && \
    echo '# Parse arguments' >> /home/tester/run_build.sh && \
    echo 'USE_PREBUILT_DJL=0' >> /home/tester/run_build.sh && \
    echo 'BUILD_ARGS=""' >> /home/tester/run_build.sh && \
    echo 'for arg in "$@"; do' >> /home/tester/run_build.sh && \
    echo '  if [ "$arg" = "--use-prebuilt-djl" ]; then' >> /home/tester/run_build.sh && \
    echo '    USE_PREBUILT_DJL=1' >> /home/tester/run_build.sh && \
    echo '  fi' >> /home/tester/run_build.sh && \
    echo '  BUILD_ARGS="$BUILD_ARGS $arg"' >> /home/tester/run_build.sh && \
    echo 'done' >> /home/tester/run_build.sh && \
    echo '' >> /home/tester/run_build.sh && \
    echo '# Build DJL first if using pre-built option and it does not exist' >> /home/tester/run_build.sh && \
    echo 'if [ "$USE_PREBUILT_DJL" -eq 1 ] && [ ! -d "$DJL_INSTALL_PREFIX" ]; then' >> /home/tester/run_build.sh && \
    echo '  echo "=========================================="' >> /home/tester/run_build.sh && \
    echo '  echo "Building DJL first (pre-built not found)"' >> /home/tester/run_build.sh && \
    echo '  echo "=========================================="' >> /home/tester/run_build.sh && \
    echo '  bash o/opensearch-project-ml-commons/build_djl_pytorch_v2.1.2.sh' >> /home/tester/run_build.sh && \
    echo 'fi' >> /home/tester/run_build.sh && \
    echo '' >> /home/tester/run_build.sh && \
    echo '# Run the ml-commons build script' >> /home/tester/run_build.sh && \
    echo 'echo "=========================================="' >> /home/tester/run_build.sh && \
    echo 'echo "Building ml-commons"' >> /home/tester/run_build.sh && \
    echo 'echo "=========================================="' >> /home/tester/run_build.sh && \
    echo 'bash o/opensearch-project-ml-commons/ml-commons_3.5.0.0_ubi9.7.sh $BUILD_ARGS' >> /home/tester/run_build.sh && \
    echo '' >> /home/tester/run_build.sh && \
    echo '# Copy artifacts to output directory if it exists' >> /home/tester/run_build.sh && \
    echo 'if [ -d "/output" ]; then' >> /home/tester/run_build.sh && \
    echo '  echo "Copying artifacts to /output..."' >> /home/tester/run_build.sh && \
    echo '  cp -r /home/tester/artifacts/* /output/ 2>/dev/null || true' >> /home/tester/run_build.sh && \
    echo '  echo "Build completed. Artifacts copied to /output"' >> /home/tester/run_build.sh && \
    echo 'else' >> /home/tester/run_build.sh && \
    echo '  echo "Build completed. Artifacts available in /home/tester/artifacts"' >> /home/tester/run_build.sh && \
    echo 'fi' >> /home/tester/run_build.sh && \
    chmod +x /home/tester/run_build.sh

# Set the entrypoint to run the wrapper script
ENTRYPOINT ["/bin/bash", "/home/tester/run_build.sh"]

# Default command (can be overridden)
CMD []

# Usage examples:
# Build with inline DJL:
#   docker build -t ml-commons-builder -f o/opensearch-project-ml-commons/Dockerfile .
#   docker run -v $(pwd)/output:/output ml-commons-builder
#
# Build with pre-built DJL (faster subsequent builds):
#   docker run -v $(pwd)/output:/output ml-commons-builder --use-prebuilt-djl
#
# Skip tests:
#   docker run -v $(pwd)/output:/output ml-commons-builder --skip-tests
#   docker run -v $(pwd)/output:/output ml-commons-builder --use-prebuilt-djl --skip-tests
#
# Specific version:
#   docker run -v $(pwd)/output:/output ml-commons-builder 3.5.0.0 --use-prebuilt-djl

# Made with Bob
