FROM registry.access.redhat.com/ubi9/ubi:9.7

# Set up build environment
ENV BUILD_HOME=/home/tester/build_workspace
ENV SCRIPT_PATH=/home/tester/build-scripts/o/opensearch-project-ml-commons
ENV DJL_HOME=/home/tester/.djl.ai

# ONNX Runtime will be built from source (v1.17.1)

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

# Copy IBM wheels helper script
COPY --chown=test_user:test_user install_ibm_wheels.sh /home/tester/
RUN chmod +x /home/tester/install_ibm_wheels.sh

# Set working directory to the script location
WORKDIR /home/tester/build-scripts

# Create artifacts directory on host mount point
RUN mkdir -p /home/tester/artifacts

# Create a wrapper script that patches the build script to fix IBM wheels installation
RUN echo '#!/bin/bash' > /home/tester/run_build.sh && \
    echo 'set -e' >> /home/tester/run_build.sh && \
    echo 'cd /home/tester/build-scripts' >> /home/tester/run_build.sh && \
    echo '# Create a modified version of the build script' >> /home/tester/run_build.sh && \
    echo 'cp o/opensearch-project-ml-commons/ml-commons_3.5.0.0_ubi9.7.sh /tmp/ml-commons_build.sh' >> /home/tester/run_build.sh && \
    echo '# Fix SCRIPT_PATH to point to the correct location (line 45)' >> /home/tester/run_build.sh && \
    echo 'sed -i "45s|SCRIPT_PATH=.*|SCRIPT_PATH=\"/home/tester/build-scripts/o/opensearch-project-ml-commons\"|" /tmp/ml-commons_build.sh' >> /home/tester/run_build.sh && \
    echo '# Replace the problematic pip install lines (159-165) with our helper script' >> /home/tester/run_build.sh && \
    echo 'sed -i "159,165d" /tmp/ml-commons_build.sh' >> /home/tester/run_build.sh && \
    echo 'sed -i "158a source /home/tester/install_ibm_wheels.sh" /tmp/ml-commons_build.sh' >> /home/tester/run_build.sh && \
    echo '# Run the modified build script' >> /home/tester/run_build.sh && \
    echo 'bash /tmp/ml-commons_build.sh "$@"' >> /home/tester/run_build.sh && \
    echo '# Copy artifacts' >> /home/tester/run_build.sh && \
    echo 'cp -r /home/tester/artifacts/* /output/ 2>/dev/null || echo "Build completed. Check /output for artifacts."' >> /home/tester/run_build.sh && \
    chmod +x /home/tester/run_build.sh

# Set the entrypoint to run the wrapper script
ENTRYPOINT ["/bin/bash", "/home/tester/run_build.sh"]

# Default command (can be overridden)
CMD []

# Made with Bob

