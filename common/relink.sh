#!/bin/bash

set -e

usage() {
    echo "Usage: $0 [-d (dry-run)] [-f (force)]"
    echo "-d    Show commands without executing"
    echo "-f    Execute commands"
    exit 1
}

DRY_RUN=false
FORCE=false

while getopts ":df" opt; do
    case "$opt" in
        d) DRY_RUN=true ;;
        f) FORCE=true ;;
        *) usage ;;
    esac
done

if [ "$DRY_RUN" = false ] && [ "$FORCE" = false ]; then
    usage
fi

SCRIPT_PATH="$(realpath "$0")"
BASE_DIR="$(cd "$(dirname "$SCRIPT_PATH")/.." && pwd)"
TARGET_DIR="$HOME/bin"

# Determine OS
OS=$(uname -o)
case "$OS" in
    GNU/Linux) OS_DIR_NAME="linux" ;;
    Darwin) OS_DIR_NAME="mac" ;;
    *) echo "Unsupported OS: $OS"; exit 1 ;;
esac

OS_DIR="$BASE_DIR/$OS_DIR_NAME"
COMMON_DIR="$BASE_DIR/common"

# Compute relative path from directory $1 to file $2
relpath() {
    local from="$1" to="$2"
    local common="$from" result=""

    while [ "${to#"$common"/}" = "$to" ] && [ "$common" != "/" ]; do
        common=$(dirname "$common")
        result="../$result"
    done

    if [ "$common" = "/" ]; then
        echo "${result}${to#/}"
    else
        echo "${result}${to#"$common"/}"
    fi
}

# Function to execute or show commands based on flags and return command status
run_command() {
    local cmd="$*"
    if [ "$FORCE" = true ]; then
        eval "$cmd"
        return $?
    else
        echo -e "\033[33m- $cmd\033[0m"
        return 0
    fi
}

# Ensure $HOME/bin exists
if ! run_command mkdir -p "$TARGET_DIR"; then
    echo -e "\033[31mFailed to create directory $TARGET_DIR, aborting.\033[0m"
    exit 1
fi

# Function to link files using relative paths
link_files() {
    local src_dir="$1"
    for file in "$src_dir"/*; do
        [ -f "$file" ] || continue  # skip if not a regular file
        fname=$(basename "$file")
        target="$TARGET_DIR/$fname"

        if [ -e "$target" ] && [ ! -L "$target" ]; then
            echo -e "\033[31mWarning: $target exists and is not a symlink, skipping.\033[0m"
            continue
        fi

        run_command ln -sf "$(relpath "$TARGET_DIR" "$file")" "$target"
    done
}

# Link common scripts first
COMMON_DIR="$BASE_DIR/common"
link_files "$COMMON_DIR"

# Then link OS-specific scripts, overriding common ones if needed
if [ -d "$BASE_DIR/$OS_DIR_NAME" ]; then
    OS_DIR="$BASE_DIR/$OS_DIR_NAME"
    link_files "$OS_DIR"
else
    echo -e "\033[31mNo OS-specific directory ($OS_DIR_NAME) found.\033[0m"
fi
