# ML-Commons Build Dockerfile

This Dockerfile builds the OpenSearch ml-commons plugin version 3.5.0.0 on UBI 9.7.

## Prerequisites

- Docker installed on your VM
- At least 16GB RAM recommended
- At least 50GB free disk space
- Internet connection for downloading dependencies

## Building the Docker Image

```bash
docker build -t ml-commons-builder .
```

**Note**: ONNX Runtime v1.17.1 will be built from source as part of the build process. This is required for Java bindings support on ppc64le architecture.

## Running the Container

To run the container and save the build artifacts to your host machine:

```bash
docker run --rm \
  -v $(pwd)/output:/output \
  ml-commons-builder
```

This will:
1. Clone the repository `irapandey/build-scripts`
2. Checkout the `workflow-irapandey` branch
3. Execute the build script `o/opensearch-project-ml-commons/ml-commons_3.5.0.0_ubi9.7.sh`
4. Copy the resulting zip file to `./output` directory on your host machine

## Build Artifacts

After successful build, you'll find the ml-commons plugin zip file in the `./output` directory:
- `opensearch-ml-plugin-3.5.0.0.zip` (or similar naming)

## Skipping Tests

To skip tests and speed up the build:

```bash
docker run --rm \
  -v $(pwd)/output:/output \
  ml-commons-builder \
  /bin/bash -c "cd /home/tester/build-scripts && bash o/opensearch-project-ml-commons/ml-commons_3.5.0.0_ubi9.7.sh --skip-tests && cp -r /home/tester/artifacts/* /output/"
```

## Troubleshooting

### Build takes too long
- The build process can take 2-4 hours depending on your VM resources
- Consider using `--skip-tests` flag to reduce build time

### Out of memory errors
- Increase Docker memory limit to at least 16GB
- Close other applications to free up system resources

### Permission errors
- Ensure the output directory has write permissions
- Run: `mkdir -p output && chmod 777 output`

## Build Process Overview

The build script performs the following steps:
1. Installs JDK 17 and JDK 21
2. Builds ONNX Runtime with Java bindings
3. Installs PyTorch and dependencies
4. Builds DJL (Deep Java Library) with PyTorch engine
5. Builds OpenSearch distribution
6. Builds Job Scheduler plugin
7. Builds Remote Metadata SDK
8. Builds ml-commons plugin
9. Runs unit and integration tests (unless skipped)
10. Collects build artifacts

## Notes

- The container runs as `test_user` (non-root) as required by the build script
- All build artifacts are collected in `/home/tester/artifacts` inside the container
- The entrypoint automatically copies artifacts to the mounted `/output` volume
- **Build Optimizations**:
  - Direct wheel downloads for abseil_cpp and libprotobuf from IBM repository
  - Fixes pip index content-type issues
- ONNX Runtime v1.17.1 is built from source with Java bindings for ppc64le
- Build process takes approximately 2-4 hours depending on VM resources

# Made with Bob
