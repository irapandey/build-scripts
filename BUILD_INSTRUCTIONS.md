# Building OpenSearch Docker Image

## Prerequisites

Before building the image, you need:

1. **Docker installed** (with BuildKit support for secrets)
2. **Required files in the build directory:**
   - `opensearch-core-<arch>.tgz` - OpenSearch tarball (architecture-specific)
   - `opensearch-docker-entrypoint-*.x.sh` - Entrypoint scripts
   - `opensearch-onetime-setup.sh` - Setup script
   - `log4j2.properties` - Log4j configuration
   - `opensearch.yml` - OpenSearch configuration
   - `performance-analyzer.properties` - Performance analyzer config
   - Plugin zip files:
     - `opensearch-knn-3.5.0.0.zip`
     - `opensearch-neural-search-3.5.0.0-SNAPSHOT.zip`
     - `opensearch-ml-3.5.0.0-SNAPSHOT.zip`
     - `opensearch-job-scheduler-3.5.0.0-SNAPSHOT.zip`
     - `build-artifacts-opensearch-project-security-v3.5.0.0.zip`

3. **JFrog Artifactory credentials** (for downloading additional plugins)

## Build Command

### Basic Build (with secrets)

```bash
# Create secret files
echo "your_artifactory_username" > artifactory_user.txt
echo "your_artifactory_token" > artifactory_token.txt

# Build the image
DOCKER_BUILDKIT=1 docker build \
  --secret id=artifactory_user_secret,src=artifactory_user.txt \
  --secret id=artifactory_token_secret,src=artifactory_token.txt \
  --build-arg VERSION=3.5.0 \
  --build-arg BUILD_DATE=$(date -u +'%Y-%m-%dT%H:%M:%SZ') \
  --build-arg NOTES="OpenSearch 3.5.0 with plugins" \
  -f DockerfileOPENSEARH.cleaned \
  -t opensearch:3.5.0 \
  .

# Clean up secret files
rm artifactory_user.txt artifactory_token.txt
```

### Build with Custom UID/GID

```bash
DOCKER_BUILDKIT=1 docker build \
  --secret id=artifactory_user_secret,src=artifactory_user.txt \
  --secret id=artifactory_token_secret,src=artifactory_token.txt \
  --build-arg VERSION=3.5.0 \
  --build-arg BUILD_DATE=$(date -u +'%Y-%m-%dT%H:%M:%SZ') \
  --build-arg UID=2000 \
  --build-arg GID=2000 \
  -f DockerfileOPENSEARH.cleaned \
  -t opensearch:3.5.0 \
  .
```

### Build with Custom OpenSearch Home

```bash
DOCKER_BUILDKIT=1 docker build \
  --secret id=artifactory_user_secret,src=artifactory_user.txt \
  --secret id=artifactory_token_secret,src=artifactory_token.txt \
  --build-arg VERSION=3.5.0 \
  --build-arg BUILD_DATE=$(date -u +'%Y-%m-%dT%H:%M:%SZ') \
  --build-arg OPENSEARCH_HOME=/opt/opensearch \
  -f DockerfileOPENSEARH.cleaned \
  -t opensearch:3.5.0 \
  .
```

## Build Arguments

| Argument | Required | Default | Description |
|----------|----------|---------|-------------|
| `VERSION` | Yes | - | OpenSearch version (e.g., 3.5.0) |
| `BUILD_DATE` | Yes | - | Build timestamp in RFC3339 format |
| `NOTES` | No | - | Additional description for the image |
| `UID` | No | 1000 | User ID for opensearch user |
| `GID` | No | 1000 | Group ID for opensearch group |
| `OPENSEARCH_HOME` | No | /usr/share/opensearch | OpenSearch installation directory |
| `DISABLE_INSTALL_DEMO_CONFIG` | No | true | Disable demo security config |
| `DISABLE_SECURITY_PLUGIN` | No | false | Disable security plugin |

## Running the Built Image

### Basic Run

```bash
docker run -d \
  --name opensearch \
  -p 9200:9200 \
  -p 9300:9300 \
  -e "discovery.type=single-node" \
  opensearch:3.5.0
```

### Run with Custom Configuration

```bash
docker run -d \
  --name opensearch \
  -p 9200:9200 \
  -p 9300:9300 \
  -e "discovery.type=single-node" \
  -e "OPENSEARCH_JAVA_OPTS=-Xms512m -Xmx512m" \
  -v opensearch-data:/usr/share/opensearch/data \
  opensearch:3.5.0
```

### Run on OpenShift

The image is OpenShift-compatible with random UID support:

```bash
oc new-app opensearch:3.5.0
```

## Troubleshooting

### Build fails with "secret not found"

Ensure you're using `DOCKER_BUILDKIT=1` and the secret files exist:
```bash
export DOCKER_BUILDKIT=1
ls -la artifactory_user.txt artifactory_token.txt
```

### Build fails with "opensearch-core-*.tgz not found"

Ensure the OpenSearch tarball is in the build context with the correct architecture:
- For x86_64: `opensearch-core-x86_64.tgz`
- For aarch64: `opensearch-core-aarch64.tgz`

### Plugin installation fails

Check that all required plugin zip files are present in the build directory.

### Permission denied errors

The image uses UID/GID 1000 by default. If you need different IDs, use the `--build-arg` flags.

## Verifying the Build

After building, verify the image:

```bash
# Check image exists
docker images opensearch:3.5.0

# Inspect image labels
docker inspect opensearch:3.5.0 | jq '.[0].Config.Labels'

# Test run
docker run --rm opensearch:3.5.0 opensearch --version
```

## Security Notes

1. **Never commit secret files** to version control
2. **Use environment variables** or secret management tools in CI/CD
3. **Rotate credentials** regularly
4. **Use minimal base images** (already using UBI 9)
5. **Scan images** for vulnerabilities after building

## Example CI/CD Integration

### GitHub Actions

```yaml
- name: Build OpenSearch Image
  env:
    ARTIFACTORY_USER: ${{ secrets.ARTIFACTORY_USER }}
    ARTIFACTORY_TOKEN: ${{ secrets.ARTIFACTORY_TOKEN }}
  run: |
    echo "$ARTIFACTORY_USER" > artifactory_user.txt
    echo "$ARTIFACTORY_TOKEN" > artifactory_token.txt
    
    DOCKER_BUILDKIT=1 docker build \
      --secret id=artifactory_user_secret,src=artifactory_user.txt \
      --secret id=artifactory_token_secret,src=artifactory_token.txt \
      --build-arg VERSION=3.5.0 \
      --build-arg BUILD_DATE=$(date -u +'%Y-%m-%dT%H:%M:%SZ') \
      -f DockerfileOPENSEARH.cleaned \
      -t opensearch:3.5.0 \
      .
    
    rm artifactory_user.txt artifactory_token.txt
```

### Jenkins

```groovy
withCredentials([
    string(credentialsId: 'artifactory-user', variable: 'ARTIFACTORY_USER'),
    string(credentialsId: 'artifactory-token', variable: 'ARTIFACTORY_TOKEN')
]) {
    sh '''
        echo "$ARTIFACTORY_USER" > artifactory_user.txt
        echo "$ARTIFACTORY_TOKEN" > artifactory_token.txt
        
        DOCKER_BUILDKIT=1 docker build \
          --secret id=artifactory_user_secret,src=artifactory_user.txt \
          --secret id=artifactory_token_secret,src=artifactory_token.txt \
          --build-arg VERSION=3.5.0 \
          --build-arg BUILD_DATE=$(date -u +'%Y-%m-%dT%H:%M:%SZ') \
          -f DockerfileOPENSEARH.cleaned \
          -t opensearch:3.5.0 \
          .
        
        rm artifactory_user.txt artifactory_token.txt
    '''
}