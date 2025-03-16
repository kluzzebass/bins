#!/bin/bash

# Check if the current directory is a git repository
if [ ! -d ".git" ]; then
    echo "This is not a git repository."
    exit 1
fi

# Get a list of all branches (local and remote), excluding tags
branches=$(git for-each-ref --format='%(refname:short)' refs/heads/ refs/remotes/)

# Declare an array to hold branch information
declare -a branch_info

# Iterate over each branch
for branch in $branches; do
    # Remove any '*' from the current branch and trim spaces
    branch=$(echo "$branch" | sed 's/*//' | xargs)

    # Skip specific branches and their remote-tracking counterparts
    case "$branch" in
        main|master|HEAD|development|production|staging|origin/main|origin/master|origin/HEAD|origin/development|origin/production|origin/staging)
            continue
            ;;
    esac

    # Get the last commit details for the branch
    last_commit=$(git log -1 --pretty=format:"%at %h - %an, %ar : %s" "$branch")

    # Add the branch name to the commit info
    branch_info+=("$last_commit $branch")
done

# Sort the branches by the commit timestamp (newest to oldest)
IFS=$'\n' sorted_branches=($(sort -r <<<"${branch_info[*]}"))

echo "Last commits for all branches (sorted by newest to oldest):"

# Print the sorted branches with the delete command suggestion
for branch in "${sorted_branches[@]}"; do
    commit_timestamp=$(echo "$branch" | awk '{print $1}')
    commit_info=$(echo "$branch" | cut -d' ' -f2-)
    branch_name=$(echo "$branch" | awk '{print $NF}')

    # Extract the 'When, who, commit message' for the delete suggestion
    when_who_commit=$(echo "$commit_info" | cut -d'-' -f2- | sed 's/^ //')

    # Check if it's a remote-tracking branch
    if [[ "$branch_name" == origin/* ]]; then
        # Retain the 'origin/' prefix to get the correct branch name
        echo "git branch -dr ${branch_name} # $when_who_commit"
    else
        # Print the local branch delete suggestion
        echo "git branch -D ${branch_name} # $when_who_commit"
    fi
done

