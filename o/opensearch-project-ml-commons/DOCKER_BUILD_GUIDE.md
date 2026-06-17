# Docker Build Guide for ml-commons

This guide explains how to build ml-commons using Docker with the fixed DJL PyTorch integration.

## Overview

The Dockerfile provides a containerized build environment for ml-commons on ppc64le architecture with:
- UBI 9.7 base image
- DJL v0.33.0 with PyTorch v2.1.2
- ONNX Runtime v1.17.1
- All required dependencies pre-configured

## Quick Start

### Build the Docker Image

```bash
cd /path/to/build-scripts
docker build -t ml-commons-builder -f o/opensearch-project-ml-commons/Dockerfile .
```

### Run the Build

#### Option 1: Standard Build (Inline DJL)
```bash
docker run -v $(pwd)/output:/output ml-commons-builder
```

#### Option 2: With Pre-built DJL (Faster)
```bash
docker run -v $(pwd)/output:/output ml-commons-builder --use-prebuilt-djl
```

#### Option 3: Skip Tests
```bash
docker run -v $(pwd)/output:/output ml-commons-builder --skip-tests
```

#### Option 4: Combine Options
```bash
docker run -v $(pwd)/output:/output ml-commons-builder --use-prebuilt-djl --skip-tests
```

## Build Options

### Command-Line Arguments

The Docker container accepts the same arguments as the build script:

| Argument | Description |
|----------|-------------|
| `--use-prebuilt-djl` | Use pre-built DJL (builds it first if not found) |
| `--skip-tests` | Skip unit and integration tests |
| `<version>` | Specify ml-commons version (default: 3.5.0.0) |

### Examples

```bash
# Build specific version
docker run -v $(pwd)/output:/output ml-commons-builder 3.5.0.0

# Build with all optimizations
docker run -v $(pwd)/output:/output ml-commons-builder 3.5.0.0 --use-prebuilt-djl --skip-tests

# Build and keep container for debugging
docker run -it -v $(pwd)/output:/output ml-commons-builder --skip-tests
```

## How It Works

### Build Process

1. **Image Build Phase** (one-time):
   - Sets up UBI 9.7 environment
   - Creates test_user with sudo privileges
   - Clones build-scripts repository
   - Prepares build wrapper script

2. **Container Run Phase** (each build):
   - Checks if `--use-prebuilt-djl` is specified
   - If yes and DJL not found, builds DJL first
   - Runs ml-commons build script with specified options
   - Copies artifacts to `/output` volume

### Pre-built DJL Workflow

When using `--use-prebuilt-djl`:

```
Container Start
    ↓
Check if DJL exists at ~/.local/djl-pytorch-2.1.2/
    ↓
    ├─ No → Build DJL (30-45 min)
    │        ↓
    │   Cache in container
    │        ↓
    └─ Yes → Skip DJL build
         ↓
Build ml-commons (15-20 min)
    ↓
Copy artifacts to /output
```

## Directory Structure

### Inside Container

```
/home/tester/
├── build-scripts/                    # Cloned repository
│   └── o/opensearch-project-ml-commons/
│       ├── ml-commons_3.5.0.0_ubi9.7.sh
│       ├── build_djl_pytorch_v2.1.2.sh
│       ├── djl_v0.33.0.patch
│       └── ml-commons_3.5.0.0.patch
├── build_workspace/                  # Build artifacts
│   ├── djl/
│   ├── onnxruntime/
│   ├── OpenSearch/
│   └── ml-commons/
├── artifacts/                        # Final build outputs
├── .djl.ai/                         # DJL runtime libraries
│   └── pytorch/2.1.2-cpu-linux-ppc64le/
├── .local/                          # DJL installation
│   └── djl-pytorch-2.1.2/
│       ├── lib/
│       ├── maven/
│       └── setup-env.sh
└── .m2/repository/                  # Maven local repo
    └── ai/djl/
```

### Host Mount Point

```
./output/                            # Mounted from host
└── opensearch-ml-plugin-*.zip      # Built plugin
```

## Advanced Usage

### Persistent DJL Cache

To persist the DJL build across container runs:

```bash
# Create a named volume for DJL
docker volume create djl-cache

# Run with volume mounted
docker run \
  -v $(pwd)/output:/output \
  -v djl-cache:/home/tester/.local \
  ml-commons-builder --use-prebuilt-djl
```

This caches the DJL build, making subsequent runs much faster.

### Interactive Debugging

```bash
# Run container interactively
docker run -it \
  -v $(pwd)/output:/output \
  --entrypoint /bin/bash \
  ml-commons-builder

# Inside container, run build manually
cd /home/tester/build-scripts
bash o/opensearch-project-ml-commons/ml-commons_3.5.0.0_ubi9.7.sh --skip-tests
```

### Multi-stage Build

For CI/CD pipelines, use a multi-stage approach:

```bash
# Stage 1: Build DJL (cache this layer)
docker build --target djl-builder -t djl-base -f o/opensearch-project-ml-commons/Dockerfile .

# Stage 2: Build ml-commons using cached DJL
docker build -t ml-commons-builder -f o/opensearch-project-ml-commons/Dockerfile .
docker run -v $(pwd)/output:/output ml-commons-builder --use-prebuilt-djl
```

### Custom Build Script Location

If you've modified the build scripts locally:

```bash
# Copy local scripts into container
docker run \
  -v $(pwd)/output:/output \
  -v $(pwd)/o/opensearch-project-ml-commons:/home/tester/custom-scripts:ro \
  ml-commons-builder
```

## Build Times

| Scenario | Time | Notes |
|----------|------|-------|
| First build (inline DJL) | 45-60 min | Builds everything |
| First build (--use-prebuilt-djl) | 45-60 min | Builds DJL, then ml-commons |
| Subsequent build (cached DJL) | 15-20 min | Reuses DJL from volume |
| With --skip-tests | -10 min | Saves test execution time |

## Troubleshooting

### Build Fails with CMake Error

**Error:**
```
CMake Error: Could not find a package configuration file provided by "Torch"
```

**Solution:**
This should be fixed in the updated scripts. If you still see this error:
1. Ensure you're using the latest Dockerfile
2. Rebuild the Docker image: `docker build --no-cache -t ml-commons-builder -f o/opensearch-project-ml-commons/Dockerfile .`

### Out of Disk Space

**Error:**
```
No space left on device
```

**Solution:**
```bash
# Clean up Docker
docker system prune -a

# Increase Docker disk space (Docker Desktop)
# Settings → Resources → Disk image size
```

### Container Exits Immediately

**Solution:**
```bash
# Check logs
docker logs <container-id>

# Run interactively to debug
docker run -it --entrypoint /bin/bash ml-commons-builder
```

### Artifacts Not Copied

**Solution:**
```bash
# Ensure output directory exists and has correct permissions
mkdir -p output
chmod 777 output

# Run with explicit volume mount
docker run -v "$(pwd)/output:/output" ml-commons-builder
```

## CI/CD Integration

### GitHub Actions Example

```yaml
name: Build ml-commons

on: [push, pull_request]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v2
      
      - name: Build Docker image
        run: |
          docker build -t ml-commons-builder \
            -f o/opensearch-project-ml-commons/Dockerfile .
      
      - name: Build ml-commons
        run: |
          mkdir -p output
          docker run -v $(pwd)/output:/output \
            ml-commons-builder --use-prebuilt-djl --skip-tests
      
      - name: Upload artifacts
        uses: actions/upload-artifact@v3
        with:
          name: ml-commons-plugin
          path: output/*.zip
```

### Jenkins Pipeline Example

```groovy
pipeline {
    agent any
    
    stages {
        stage('Build Docker Image') {
            steps {
                sh '''
                    docker build -t ml-commons-builder \
                        -f o/opensearch-project-ml-commons/Dockerfile .
                '''
            }
        }
        
        stage('Build ml-commons') {
            steps {
                sh '''
                    mkdir -p output
                    docker run -v $(pwd)/output:/output \
                        ml-commons-builder --use-prebuilt-djl --skip-tests
                '''
            }
        }
        
        stage('Archive Artifacts') {
            steps {
                archiveArtifacts artifacts: 'output/*.zip', fingerprint: true
            }
        }
    }
}
```

## Performance Tips

1. **Use Volume Caching**: Mount volumes for `.m2`, `.djl.ai`, and `.local` to cache builds
2. **Enable BuildKit**: `export DOCKER_BUILDKIT=1` for faster builds
3. **Use --use-prebuilt-djl**: Saves 30-45 minutes on subsequent builds
4. **Skip Tests in Development**: Use `--skip-tests` for faster iteration
5. **Multi-stage Builds**: Separate DJL and ml-commons builds for better caching

## Support

For issues or questions:
1. Check the troubleshooting section above
2. Review build logs: `docker logs <container-id>`
3. Run interactively for debugging: `docker run -it --entrypoint /bin/bash ml-commons-builder`
4. Verify all patches are applied correctly

## License

Apache License, Version 2.0 or later