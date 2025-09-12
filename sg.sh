#!/usr/bin/env bash

# Combined git management script for tags and branches
# Merges functionality from ww-tag.sh and wwg.sh

# --- Configuration ---
# Default starting tag if no tags are found or no applicable base tag.
# DEFAULT_START_TAG="0.0.1-dev-release"
# --- End Configuration ---

# Global variable for the new tag name, to be set by create_and_tag
new_tag=""

print_help() {
  echo "Usage: $(basename "$0") [OPTION]"
  echo "Combined git management script for tags and branches."
  echo
  echo "Tag Management Options:"
  echo "  -a             Create a new dev-release tag. The version is incremented"
  echo "                 based on the latest repository tag (either X.Y.Z-dev-release or X.Y.Z)."
  echo "                 If no tags exist, starts with 0.0.1-dev-release."
  echo "  -ap            Create a new dev-release tag (like -a) and then push the new tag"
  echo "                 to the 'origin' remote."
  echo "  -p             Push all local tags to the 'origin' remote."
  echo "  -s, --sync     Pull changes for the current branch from 'origin' and then force-fetch"
  echo "                 all tags from 'origin', overriding any local tags with remote values"
  echo "                 and pruning any local tags that no longer exist remotely."
  echo
  echo "Branch Management Options:"
  echo "  -db            Delete all local branches not included in the remote."
  echo "                 This will:"
  echo "                 1. Fetch and prune remote tracking branches"
  echo "                 2. Delete merged local branches (except current, main, master)"
  echo "                 3. Force delete branches whose remote tracking branch is gone"
  echo "  -lb            List all remote branches sorted by commit date"
  echo
  echo "General Options:"
  echo "  -h, --help     Show this help message and exit."
  echo
  echo "Examples:"
  echo "  $(basename "$0") -a"
  echo "  $(basename "$0") -ap"
  echo "  $(basename "$0") -p"
  echo "  $(basename "$0") -s"
  echo "  $(basename "$0") -db"
  echo "  $(basename "$0") -lb"
  echo
  echo "Tagging Logic:"
  echo "  - If latest tag is X.Y.Z-dev-release, next is X.Y.(Z+1)-dev-release."
  echo "  - If latest tag is X.Y.Z, next is X.Y.(Z+1)-dev-release."
  echo "  - If no tags or no suitable base tag, starts from 0.0.1-dev-release."
}

# Function to create the new tag
create_and_tag() {
  # Ensure we are in a git repository and there's a commit to tag
  if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
    echo "Error: Not a git repository (or any of the parent directories)."
    return 1
  fi
  if ! git rev-parse HEAD >/dev/null 2>&1; then
    echo "Error: No commits in the repository to tag at HEAD."
    return 1
  fi

  # Get the most recently created tag in the entire repository
  # This could be any tag format. We'll check its pattern next.
  latest_tag_overall=$(git for-each-ref --sort=-creatordate --count=1 --format='%(refname:short)' refs/tags)

  if [ -z "$latest_tag_overall" ]; then
    echo "No tags found in the repository. Starting with 0.0.1-dev-release."
    new_tag="0.0.1-dev-release"
  else
    # Check if latest_tag_overall is X.Y.Z-dev-release
    if echo "$latest_tag_overall" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+-dev-release$'; then
      new_tag=$(echo "$latest_tag_overall" | awk -F'[.-]' '{printf "%s.%s.%d-%s-%s\n", $1, $2, $3+1, $4, $5}')
    # Check if latest_tag_overall is X.Y.Z
    elif echo "$latest_tag_overall" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]$'; then
      echo "Info: Latest tag ('$latest_tag_overall') is a release tag (X.Y.Z)."
      echo "Creating next dev-release based on it."
      new_tag=$(echo "$latest_tag_overall" | awk -F'.' '{printf "%s.%s.%d-dev-release\n", $1, $2, $3+1}')
    else
      echo "Error: Latest tag ('$latest_tag_overall') is not in a recognized format for auto-increment:"
      echo "       (expected X.Y.Z-dev-release or X.Y.Z)."
      echo "       Cannot automatically determine the next dev-release tag."
      echo "       Consider creating the first dev-release tag manually (e.g., '0.0.1-dev-release')."
      return 1
    fi
  fi

  if [ -z "$new_tag" ]; then
    echo "Internal Error: Failed to calculate new_tag. Latest overall tag was '$latest_tag_overall'."
    return 1
  fi

  # Loop to find a non-existent tag by incrementing if necessary
  while true; do
    if git rev-parse -q --verify "refs/tags/$new_tag" >/dev/null 2>&1; then
      echo "Info: Tag '$new_tag' already exists. Attempting to increment to the next version."
      # Increment the patch version of the current new_tag (should be X.Y.Z-dev-release)
      local incremented_tag
      incremented_tag=$(echo "$new_tag" | awk -F'[.-]' '{printf "%s.%s.%d-%s-%s\n", $1, $2, $3+1, $4, $5}')

      if [ -z "$incremented_tag" ]; then
          echo "Internal Error: Failed to increment tag '$new_tag' during existence check."
          return 1
      fi
      new_tag="$incremented_tag" # Update new_tag and loop again
    else
      # Tag does not exist, this is the one we'll use.
      echo "Info: Using available tag '$new_tag'."
      break
    fi
  done

  echo "Attempting to tag current HEAD with '$new_tag'..."
  if git tag "$new_tag" HEAD; then
    echo "Successfully tagged HEAD with '$new_tag'."
    return 0 # Success
  else
    echo "Error: Failed to tag HEAD with '$new_tag'. 'git tag' command failed."
    return 1 # Failure
  fi
}

# Function to push the new tag
push_new_tag() {
  if [ -z "$new_tag" ]; then
    echo "Error: No new tag was specified or created. Cannot push."
    return 1
  fi
  echo "Pushing tag '$new_tag' to origin..."
  if git push origin "$new_tag"; then
    echo "Successfully pushed tag '$new_tag' to origin."
  else
    echo "Error: Failed to push tag '$new_tag' to origin."
    return 1
  fi
}

# Function to push all local tags to origin
push_all_tags() {
  echo "Attempting to push all local tags to origin..."
  if git push origin --tags; then
    echo "Successfully pushed all local tags to origin."
    return 0
  else
    echo "Error: Failed to push all local tags to origin."
    return 1
  fi
}

# Function to sync repository (pull current branch) and all tags with origin
sync_repository_and_tags() {
  echo "Attempting to sync repository and tags with origin..."

  current_branch=$(git rev-parse --abbrev-ref HEAD)
  if [ -z "$current_branch" ] || [ "$current_branch" = "HEAD" ]; then
    echo "Error: Could not determine current branch or in detached HEAD state. Cannot pull."
    # We can still try to fetch tags
  else
    echo "Pulling changes for current branch ('$current_branch') from origin..."
    if git pull origin "$current_branch"; then
      echo "Successfully pulled changes for branch '$current_branch'."
    else
      echo "Warning: Failed to pull changes for branch '$current_branch'. Continuing to sync tags."
      # Not returning 1 here, as tag sync might still be desired/possible
    fi
  fi

  echo "Force-fetching all tags from origin (remote tags will override local tags)..."
  if git fetch origin --tags --force; then
    echo "Successfully fetched tags from origin with force update."
    
    # Also prune any local tags that don't exist on remote
    echo "Pruning local tags that don't exist on remote..."
    if git fetch origin --prune --prune-tags; then
      echo "Successfully pruned local tags not on remote."
    else
      echo "Warning: Failed to prune local tags. Tags may be out of sync."
    fi
    
    return 0
  else
    echo "Error: Failed to force-fetch tags from origin."
    return 1
  fi
}

# Function to delete branches
delete_branches() {
    echo "🔄 Fetching and pruning remote branches..."
    git fetch --prune
    
    echo "🗑️  Deleting merged local branches..."
    git branch --merged | grep -v "\*\|main\|master" | xargs -n 1 git branch -d
    
    echo "🗑️  Force deleting branches with gone remote tracking..."
    git for-each-ref --format '%(refname:short) %(upstream:track)' refs/heads | awk '$2 == "[gone]" {print $1}' | xargs -r git branch -D
    
    echo "✅ Branch cleanup completed!"
}

# Function to list branches
list_branches() {
    echo "🔄 Listing branches..."
    echo "🔄 "
    echo "--------------------------------"
    echo "DATE      |AUTHOR              |BRANCH" | column -t -s '|'
    echo "--------------------------------"
    git for-each-ref --sort=-committerdate --format='%(committerdate:short)|%(authorname)|%(refname:short)' refs/remotes | column -t -s '|' | sort -k1 -r
    echo "--------------------------------"
}

# Main script logic
if [ "$#" -eq 0 ]; then
  echo "Error: No option provided."
  print_help
  exit 1
fi

case "$1" in
  # Tag management options
  -a)
    if ! create_and_tag; then
      exit 1
    fi
    ;;
  -ap)
    if create_and_tag; then
      if ! push_new_tag; then
        exit 1
      fi
    else
      echo "Tag creation failed, skipping push."
      exit 1
    fi
    ;;
  -p)
    if ! push_all_tags; then
      exit 1
    fi
    ;;
  -s|--sync)
    if ! sync_repository_and_tags; then
      exit 1
    fi
    ;;
  # Branch management options
  -db)
    delete_branches
    ;;
  -lb)
    list_branches
    ;;
  # Help option
  -h|--help)
    print_help
    exit 0
    ;;
  *)
    echo "Error: Invalid option '$1'."
    print_help
    exit 1
    ;;
esac

exit 0
