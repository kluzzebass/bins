#!/bin/bash

# Function to display help
show_help() {
  cat << EOF
Usage: $(basename "$0") [OPTIONS]

Options:
  -h, --help                 Display this help message.
  -d, --dry-run              Show commands without executing.
  -f, --force                Actually execute the commands.
  -p, --public               Create repository with public visibility (default is private).
  -l, --license LICENSE      Specify license template (e.g., mit, apache-2.0).
  -g, --gitignore TEMPLATE   Specify .gitignore template (e.g., Node, Python).
  -b, --branch BRANCH_NAME   Set initial branch name (default is 'main').
  --list-licenses            List available LICENSE templates.
  --list-gitignores          List available .gitignore templates.

Example:
  $(basename "$0") --force --public --license mit --gitignore Python --branch main
EOF
}

list_licenses() {
  gh api licenses --jq '.[].key'
}

list_gitignores() {
  gh api gitignore/templates --jq '.[]'
}

# Display help if no parameters are provided
if [ $# -eq 0 ]; then
  show_help
  exit 0
fi

DRY_RUN=false
EXECUTE=false
VISIBILITY="private"
LICENSE=""
GITIGNORE=""
BRANCH_NAME="main"

while [ "$#" -gt 0 ]; do
  case "$1" in
    -d|--dry-run)
      DRY_RUN=true
      ;;
    -f|--force)
      EXECUTE=true
      ;;
    -p|--public)
      VISIBILITY="public"
      ;;
    -l|--license)
      shift
      LICENSE="$1"
      ;;
    -g|--gitignore)
      shift
      GITIGNORE="$1"
      ;;
    -b|--branch)
      shift
      BRANCH_NAME="$1"
      ;;
    --list-licenses)
      list_licenses
      exit 0
      ;;
    --list-gitignores)
      list_gitignores
      exit 0
      ;;
    -h|--help)
      show_help
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      show_help
      exit 1
      ;;
  esac
  shift
done

if [ "$EXECUTE" != true ] && [ "$DRY_RUN" != true ]; then
  echo "Please specify --dry-run or --force."
  exit 1
fi

REPO_NAME=$(basename "$PWD")

# Check if GitHub CLI is installed and repository exists
if command -v gh &> /dev/null; then
  if gh repo view "$REPO_NAME" &> /dev/null; then
    echo "A GitHub repository named '$REPO_NAME' already exists."
    exit 1
  fi
else
  echo "GitHub CLI (gh) is not installed. Install it before proceeding."
  exit 1
fi

# Check if Git is installed
if ! command -v git &> /dev/null; then
  echo "Git is not installed. Please install Git first."
  exit 1
fi

# Check if current directory is already inside a Git repository
if git rev-parse --is-inside-work-tree &> /dev/null; then
  echo "This directory is already inside a Git repository."
  exit 1
fi

run_command() {
  if [ "$DRY_RUN" = true ]; then
    echo "$*"
  elif [ "$EXECUTE" = true ]; then
    eval "$*"
    return $?
  else
    echo "Neither --dry-run nor --force specified. Exiting."
    exit 1
  fi
}

# Initialize Git repository with specified branch name
run_command "git init -b $BRANCH_NAME" || { echo "Failed to initialize repository"; exit 1; }

# Create README.md
run_command "echo '# $REPO_NAME' > README.md" || { echo "Failed to create README.md"; exit 1; }

# Fetch specified .gitignore template if provided
if [ -n "$GITIGNORE" ]; then
  run_command "gh api 'gitignore/templates/$GITIGNORE' --jq '.source' > .gitignore" || { echo "Failed to fetch .gitignore template"; exit 1; }
fi

# Fetch specified LICENSE template if provided
if [ -n "$LICENSE" ]; then
  run_command "gh api 'licenses/$LICENSE' --jq '.body' > LICENSE" || { echo "Failed to fetch LICENSE template"; exit 1; }
fi

# Stage files
run_command "git add ." || { echo "Failed to stage files"; exit 1; }

# Commit files
run_command "git commit -m 'Initial commit'" || { echo "Failed to commit files"; exit 1; }

# Create repository on GitHub and push
if command -v gh &> /dev/null; then
  run_command "gh repo create '$REPO_NAME' --$VISIBILITY --source=. --remote=origin --push" || { echo "Failed to create GitHub repository"; exit 1; }
else
  echo "gh CLI not installed. Manually create the repo at https://github.com/new, then run:"
  echo "git remote add origin git@github.com:YOUR_USERNAME/$REPO_NAME.git"
  echo "git push -u origin $BRANCH_NAME"
fi
