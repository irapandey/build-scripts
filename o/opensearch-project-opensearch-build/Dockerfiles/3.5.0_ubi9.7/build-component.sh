#!/usr/bin/env bash
# =============================================================================
# build-component.sh — build/test a single OpenSearch 3.5.0 component
#
# Run this script INSIDE the build-env container (mounted at /opensearch-build).
# It is a thin wrapper around the opensearch-build ./build.sh CLI that limits
# the build to one component at a time, making it fast to iterate on failures.
#
# Usage (inside the container):
#   ./build-component.sh <component-name> [--snapshot] [--keep-build]
#
# Arguments:
#   <component-name>   Name exactly as it appears in the manifest, e.g.:
#                        OpenSearch
#                        common-utils
#                        job-scheduler
#                        security
#                        alerting
#                        cross-cluster-replication
#                        index-management
#                        k-NN
#                        ml-commons
#                        neural-search
#                        notifications-core
#                        notifications
#                        opensearch-observability
#                        opensearch-reports
#                        opensearch-learning-to-rank-base
#                        OpenSearch-DataFusion
#
#   --snapshot         Build with SNAPSHOT=true (default: false)
#   --keep-build       Do not wipe the component's build output on exit
#
# How to run it inside a container:
#   # From the host — apply the patch first, then exec into the container:
#   git -C /path/to/opensearch-build apply ppc64le-3.5.0-ai-services.patch
#   podman run --rm -it \
#       --cpus=4 --ulimit nproc=65536:65536 \
#       -v /path/to/opensearch-build:/opensearch-build:z \
#       -w /opensearch-build \
#       --entrypoint '' \
#       opensearch-build-env:3.5.0-ppc64le \
#       bash
#   # Then inside the container:
#   ./build-component.sh security
#
# Output lands under:
#   /opensearch-build/tar/builds/opensearch/
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------
MANIFEST="manifests/3.5.0/opensearch-3.5.0.yml"
PLATFORM="linux"
ARCHITECTURE="ppc64le"
VERSION="3.5.0"

# ---------------------------------------------------------------------------
# Colours
# ---------------------------------------------------------------------------
log()  { echo -e "\n\033[1;36m>>> [$(date '+%H:%M:%S')] $*\033[0m"; }
ok()   { echo -e "\033[1;32m    ✔ $*\033[0m"; }
warn() { echo -e "\033[1;33m    ⚠ $*\033[0m"; }
die()  { echo -e "\033[1;31m    ✘ $*\033[0m" >&2; exit 1; }

# ---------------------------------------------------------------------------
# Usage
# ---------------------------------------------------------------------------
usage() {
    sed -n '/^# Usage/,/^# Output/p' "$0" | grep '^#' | sed 's/^# \{0,2\}//'
    exit 1
}

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
COMPONENT=""
SNAPSHOT="false"
KEEP_BUILD=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --snapshot)    SNAPSHOT="true"; shift ;;
        --keep-build)  KEEP_BUILD=true;  shift ;;
        --help|-h)     usage ;;
        -*)
            die "Unknown flag: $1  (run with --help for usage)"
            ;;
        *)
            if [[ -z "${COMPONENT}" ]]; then
                COMPONENT="$1"
            else
                die "Unexpected positional argument: $1"
            fi
            shift
            ;;
    esac
done

[[ -n "${COMPONENT}" ]] || die "No component name given.  Usage: $0 <component-name> [--snapshot] [--keep-build]"

# ---------------------------------------------------------------------------
# Sanity checks
# ---------------------------------------------------------------------------
[[ -f "${MANIFEST}" ]] || \
    die "Manifest not found: ${MANIFEST}.  Run this script from /opensearch-build."

command -v python3 >/dev/null 2>&1 || die "python3 not found in PATH."

# Confirm the component actually exists in the manifest so we get a clear
# error instead of a cryptic opensearch-build failure.
if ! grep -qE "^\s+name:\s+${COMPONENT}\s*$" "${MANIFEST}"; then
    warn "Component '${COMPONENT}' not found in ${MANIFEST}."
    warn "Available components:"
    grep -E '^\s+name:' "${MANIFEST}" | sed 's/.*name:\s*/    /' >&2
    die "Aborting — fix the component name and retry."
fi

# ---------------------------------------------------------------------------
# Summarise what we're about to do
# ---------------------------------------------------------------------------
log "Build-component: ${COMPONENT}"
echo "  Manifest   : ${MANIFEST}"
echo "  Platform   : ${PLATFORM}"
echo "  Arch       : ${ARCHITECTURE}"
echo "  Version    : ${VERSION}"
echo "  Snapshot   : ${SNAPSHOT}"
echo "  Java home  : ${JAVA_HOME:-<not set>}"
echo ""

# ---------------------------------------------------------------------------
# Run the build
# ---------------------------------------------------------------------------
# GRADLE_OPTS is already set in the build-env image but we reinforce it here
# to cap worker threads and avoid EAGAIN errors on limited-CPU hosts.
export GRADLE_OPTS="${GRADLE_OPTS:--Dorg.gradle.workers.max=4 -Dfile.encoding=UTF-8}"

log "Running: ./build.sh ${MANIFEST} --component ${COMPONENT} --platform ${PLATFORM} --architecture ${ARCHITECTURE} --snapshot ${SNAPSHOT}"

./build.sh \
    "${MANIFEST}" \
    --component "${COMPONENT}" \
    --platform  "${PLATFORM}" \
    --architecture "${ARCHITECTURE}" \
    --snapshot "${SNAPSHOT}"

# ---------------------------------------------------------------------------
# Report output artefacts
# ---------------------------------------------------------------------------
log "Build succeeded for component: ${COMPONENT}"
OUTPUT_DIR="tar/builds/opensearch"
if [[ -d "${OUTPUT_DIR}" ]]; then
    echo ""
    echo "Output artefacts:"
    find "${OUTPUT_DIR}" -name "*.zip" -o -name "*.jar" -o -name "*.tar.gz" \
        2>/dev/null | sort | sed 's/^/  /'
fi

ok "Done — ${COMPONENT} built successfully."

# ---------------------------------------------------------------------------
# Optional cleanup
# ---------------------------------------------------------------------------
if [[ "${KEEP_BUILD}" == false ]]; then
    COMPONENT_BUILD_DIR="$(find . -maxdepth 3 -type d -name "${COMPONENT}" \
        -path '*/builds/*' 2>/dev/null | head -1)"
    if [[ -n "${COMPONENT_BUILD_DIR}" ]]; then
        warn "Removing component build dir to save space: ${COMPONENT_BUILD_DIR}"
        rm -rf "${COMPONENT_BUILD_DIR}"
    fi
fi
