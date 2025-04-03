#!/bin/bash

set -euo pipefail

# =========================
# 🧾 Usage Information
# =========================
usage() {
    echo "Usage: $(basename "$0") [options]"
    echo ""
    echo "Options:"
    echo "  -h, --help       Show this help message and exit"
    echo "  -f, --force      Force recreate containers"
    echo "  -b, --build      Build images before starting containers"
    echo "      --dry-run    Simulate actions without making changes"
}

# =========================
# 🧩 Parse Arguments First
# =========================
FORCE=""
BUILD=""
DRY_RUN=false

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

# =========================
# 📄 Find Compose File
# =========================
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

# =========================
# ✅ Validate Compose File
# =========================
if ! docker compose -f "$compose_file" config > /dev/null 2>&1; then
    echo "❌ Error: Docker Compose file '$compose_file' is invalid."
    docker compose -f "$compose_file" config
    exit 1
fi

# =========================
# 🔍 Capture Image Digests
# =========================
get_image_digest() {
    docker image inspect --format='{{index .RepoDigests 0}}' "$1" 2>/dev/null || echo ""
}

image_names=$(docker compose config | grep 'image:' | awk '{print $2}' | sort -u)

declare -A digests_before
for image in $image_names; do
    digests_before["$image"]=$(get_image_digest "$image")
done

# =========================
# 🚫 Dry Run
# =========================
if $DRY_RUN; then
    echo "🚫 Dry run mode enabled. The following would be performed:"
    echo "1. Validate Docker Compose file ✅"
    echo "2. Pull updated images"
    echo "3. Check for changes in image digests:"
    for image in "${!digests_before[@]}"; do
        echo "   - $image (before digest: ${digests_before[$image]})"
    done
    echo "4. Run: docker compose up -d $FORCE $BUILD (if any digest changed)"
    echo "5. Prune: docker image prune -f (if containers recreated)"
    exit 0
fi

# =========================
# 📦 Pull Images
# =========================
echo "📦 Pulling updated images..."
docker compose pull

# =========================
# 🔄 Compare Digests
# =========================
updated=false
for image in $image_names; do
    digest_before="${digests_before[$image]}"
    digest_after=$(get_image_digest "$image")
    if [[ "$digest_before" != "$digest_after" ]]; then
        echo "🔄 Image updated: $image"
        updated=true
    fi
done

if [[ "$updated" == false ]]; then
    echo "✅ No image changes detected. Skipping container restart and image prune."
    exit 0
fi

# =========================
# 🚀 Run docker compose up
# =========================
echo "🚀 Images updated. Running containers with: docker compose up -d $FORCE $BUILD"
before_containers=$(docker compose ps -q)
docker compose up -d $FORCE $BUILD
after_containers=$(docker compose ps -q)

# =========================
# 🧹 Image Prune (if needed)
# =========================
if [[ "$before_containers" != "$after_containers" ]]; then
    echo "🧹 Containers were recreated. Pruning dangling images..."
    docker image prune -f
else
    echo "✅ Containers were not recreated. Skipping image prune."
fi
