#!/bin/bash

set -euo pipefail

# Usage function
usage() {
    echo "Usage: $(basename "$0") [options]"
    echo ""
    echo "Options:"
    echo "  -h, --help       Show this help message and exit"
    echo "  -f, --force      Force recreate containers"
    echo "  -b, --build      Build images before starting containers"
    echo "      --dry-run    Simulate actions without making changes"
}

# Default flags
FORCE=""
BUILD=""
DRY_RUN=false

# Parse arguments before anything else
while [[ "$#" -gt 0 ]]; do
    case "$1" in
        -h|--help)
            usage
            exit 0
            ;;
        -f|--force)
            FORCE="--force-recreate"
            shift
            ;;
        -b|--build)
            BUILD="--build"
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        -*)
            echo "❌ Unknown option: $1"
            usage
            exit 1
            ;;
        *)
            break
            ;;
    esac
done

# Find valid docker compose file
compose_files=(docker-compose.yml docker-compose.yaml compose.yml compose.yaml)
compose_file=""

for file in "${compose_files[@]}"; do
    if [[ -f "$file" ]]; then
        compose_file="$file"
        break
    fi
done

if [[ -z "$compose_file" ]]; then
    echo "❌ Error: No Docker Compose file found in the current directory."
    echo "Expected one of: ${compose_files[*]}"
    exit 1
fi

echo "📄 Using Docker Compose file: $compose_file"

# Validate the file
if ! docker compose -f "$compose_file" config > /dev/null 2>&1; then
    echo "❌ Error: Docker Compose file '$compose_file' is invalid."
    docker compose -f "$compose_file" config
    exit 1
fi

# Capture image IDs before pull
before_images=$(docker compose images --quiet | sort)

if $DRY_RUN; then
    echo "🚫 Dry run mode enabled. The following would be performed:"
    echo "1. Validate Docker Compose file ✅"
    echo "2. Check for updated images"
    echo "3. Pull images: docker compose pull"
    echo "4. Compare image digests"
    echo "5. Run: docker compose up -d $FORCE $BUILD (if anything changed)"
    echo "6. Prune: docker image prune -f (if containers recreated)"
    exit 0
fi

echo "📦 Pulling updated images..."
docker compose pull

# Capture image IDs after pull
after_images=$(docker compose images --quiet | sort)

if [[ "$before_images" == "$after_images" ]]; then
    echo "✅ No image changes detected. Skipping container restart and image prune."
    exit 0
fi

echo "🚀 Images updated. Running containers with: docker compose up -d $FORCE $BUILD"
before_containers=$(docker compose ps -q)

docker compose up -d $FORCE $BUILD

after_containers=$(docker compose ps -q)

if [[ "$before_containers" != "$after_containers" ]]; then
    echo "🧹 Containers were recreated. Pruning dangling images..."
    docker image prune -f
else
    echo "✅ Containers were not recreated. Skipping image prune."
fi
