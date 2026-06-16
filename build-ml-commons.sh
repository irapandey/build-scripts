#!/bin/bash
# Helper script to build ml-commons and extract the zip file to host

set -e

echo "Building ml-commons Docker image..."
docker build -f Dockerfile.ml-commons -t ml-commons-builder:3.5.0.0 .

echo "Running container to build ml-commons..."
docker run --rm -v "$(pwd)/output:/output" ml-commons-builder:3.5.0.0

echo "Build complete! Zip file(s) available in ./output/"
ls -lh ./output/*.zip

# Made with Bob
