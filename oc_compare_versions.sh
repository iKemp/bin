#!/usr/bin/env bash

# Source the utility functions
source "$(dirname "$0")/../lib/bash/utils.sh"

# --- Main Script Logic ---
check_dependencies "oc" "gum"

# Function to get commit hash from an image stream tag using a specific context
get_commit_hash() {
  local KUBE_CONTEXT=$1
  local IMAGE_STREAM_TAG=$2 # e.g., my-app:prod

  local DESCRIBE_OUTPUT
  # Capture all output from oc describe
  if ! DESCRIBE_OUTPUT=$(oc --context="${KUBE_CONTEXT}" describe istag "${IMAGE_STREAM_TAG}" 2>/dev/null); then
    echo "" # If istag not found or error, return empty
    return 0
  fi

  # Filter for lines containing "OPENSHIFT_BUILD_COMMIT" and extract the value
  # The output typically looks like '    OPENSHIFT_BUILD_COMMIT=some_hash_value'
  echo "$DESCRIBE_OUTPUT" | \
    grep -i 'OPENSHIFT_BUILD_COMMIT=' | \
    awk -F'=' '{print $2}' | head -n 1 || true
  # Explanation:
  # grep -i 'OPENSHIFT_BUILD_COMMIT=': Finds the line with the commit variable.
  # awk -F'=' '{print $2}': Sets the field separator to '=' and prints the second field (the value).
  # head -n 1: Ensures only the first occurrence is taken, in case there are multiple.
  # || true: Prevents pipefail if the grep or awk doesn't find a match.
}

# --- Main Script ---

gum style \
	--foreground "#04B575" --border-foreground "#04B575" --border double \
	--align center --width 60 --margin "1 2" --padding "1 2" \
	"OpenShift ImageStream Version Comparison" "Across Contexts (All ImageStreams)"

echo ""

# Get all available contexts
ALL_CONTEXTS=$(oc config get-contexts -o name || true)
if [ -z "$ALL_CONTEXTS" ]; then
    gum style --foreground "204" "No OpenShift contexts found in your kubeconfig. Please ensure you are logged in to some clusters."
    exit 1
fi

### Select Contexts

# Apply optional filter pattern for contexts
CONTEXT_FILTER_PATTERN=$(gum input --placeholder "Enter context name filter (e.g., 'dev-', 'prod', 'myteam'):" --value "$1")

gum style --foreground "#04B575" "Select Source Cluster Context:"
# Filter contexts if a pattern was provided
if [ -n "$CONTEXT_FILTER_PATTERN" ]; then
    FILTERED_CONTEXTS=$(echo "$ALL_CONTEXTS" | grep -i "$CONTEXT_FILTER_PATTERN" || true)
    if [ -z "$FILTERED_CONTEXTS" ]; then
        gum style --foreground "204" "No contexts found matching '$CONTEXT_FILTER_PATTERN'. Exiting."
        exit 1
    fi
    SOURCE_CONTEXT=$(echo "$FILTERED_CONTEXTS" | gum choose --limit=1 --height 10 --header "Choose source context matching '$CONTEXT_FILTER_PATTERN'")
else
    SOURCE_CONTEXT=$(echo "$ALL_CONTEXTS" | gum choose --limit=1 --height 10 --header "Choose source context")
fi

if [ -z "$SOURCE_CONTEXT" ]; then
    gum style --foreground "204" "Source context selection cancelled. Exiting."
    exit 1
fi

gum style --foreground "#04B575" "Select Target Cluster Context:"
# Filter contexts for target, excluding the already selected source
if [ -n "$CONTEXT_FILTER_PATTERN" ]; then
    FILTERED_CONTEXTS_TARGET=$(echo "$ALL_CONTEXTS" | grep -i "$CONTEXT_FILTER_PATTERN" | grep -v "$SOURCE_CONTEXT" || true)
    if [ -z "$FILTERED_CONTEXTS_TARGET" ]; then
        gum style --foreground "204" "No *other* contexts found matching '$CONTEXT_FILTER_PATTERN'. Exiting."
        exit 1
    fi
    TARGET_CONTEXT=$(echo "$FILTERED_CONTEXTS_TARGET" | gum choose --limit=1 --height 10 --header "Choose target context matching '$CONTEXT_FILTER_PATTERN'")
else
    TARGET_CONTEXT=$(echo "$ALL_CONTEXTS" | grep -v "$SOURCE_CONTEXT" | gum choose --limit=1 --height 10 --header "Choose target context")
fi

if [ -z "$TARGET_CONTEXT" ]; then
    gum style --foreground "204" "Target context selection cancelled. Exiting."
    exit 1
fi

gum style --foreground "204" "Selected Source: ${SOURCE_CONTEXT}"
gum style --foreground "204" "Selected Target: ${TARGET_CONTEXT}"

### Discover ImageStreams

# Determine the project for the source context to get ImageStreams from
SOURCE_PROJECT=$(oc --context="${SOURCE_CONTEXT}" project -q 2>/dev/null || true)
if [ -z "$SOURCE_PROJECT" ]; then
    gum style --foreground "204" "Could not determine the current project for context '${SOURCE_CONTEXT}'. Please ensure a project is set for this context."
    exit 1
fi
gum style --foreground "240" "ImageStreams will be fetched from the current project of the source context: ${SOURCE_PROJECT}"

gum style --foreground "#04B575" "Discovering ImageStreams in context '${SOURCE_CONTEXT}' (project: '${SOURCE_PROJECT}')..."
IMAGE_STREAMS=$(oc --context="${SOURCE_CONTEXT}" get is -o custom-columns=":metadata.name" --no-headers 2>/dev/null | grep -v 'openshift' || true)

if [ -z "$IMAGE_STREAMS" ]; then
    gum style --foreground "204" "No user-defined ImageStreams found in project '${SOURCE_PROJECT}' for context '${SOURCE_CONTEXT}'. Exiting."
    exit 1
fi

### Start Comparison

# Image tags to compare
IMAGE_TAGS=("latest" "stage" "prod")

num_imagestreams=$(echo "$IMAGE_STREAMS" | wc -l | tr -d '[:space:]')
#gum style --foreground "04B575" --margin "1 0" --padding "0 1" "--- Starting comparison for 21 ImageStreams ---"
gum style --foreground "04B575" --margin "1 0" --padding "0 1" "  --- Starting comparison for ${num_imagestreams} ImageStreams ---  "

echo "$IMAGE_STREAMS" | while IFS= read -r IS_NAME; do
    gum style --foreground "04B575" --margin "1 0" --padding "0 1" "Comparing ImageStream: ${IS_NAME}"

    for TAG in "${IMAGE_TAGS[@]}"; do
        FULL_IMAGE_STREAM_TAG="${IS_NAME}:${TAG}"

        gum style --foreground "240" "  --- Checking tag: ${TAG} ---"

        # Fetch commit hashes
        SOURCE_COMMIT=$(get_commit_hash "$SOURCE_CONTEXT" "$FULL_IMAGE_STREAM_TAG")
        TARGET_COMMIT=$(get_commit_hash "$TARGET_CONTEXT" "$FULL_IMAGE_STREAM_TAG")
        #echo $SOURCE_COMMIT
        #echo $TARGET_COMMIT

        gum style --foreground "240" "  Source Cluster (Context: $SOURCE_CONTEXT): $( [ -n "$SOURCE_COMMIT" ] && echo "$SOURCE_COMMIT" || echo "Not Found" )"
        gum style --foreground "240" "  Target Cluster (Context: $TARGET_CONTEXT): $( [ -n "$TARGET_COMMIT" ] && echo "$TARGET_COMMIT" || echo "Not Found" )"

        if [[ -z "$SOURCE_COMMIT" && -z "$TARGET_COMMIT" ]]; then
            gum style --foreground "220" "  Result: Neither cluster has this tag." # Yellow
        elif [[ -z "$SOURCE_COMMIT" ]]; then
            gum style --foreground "204" "  Result: Tag found only on Target Cluster." # Red
        elif [[ -z "$TARGET_COMMIT" ]]; then
            gum style --foreground "204" "  Result: Tag found only on Source Cluster." # Red
        elif [[ "$SOURCE_COMMIT" == "$TARGET_COMMIT" ]]; then
            gum style --foreground "005" "  Result: MATCH - Versions are identical." # Pink
        else
            gum style --foreground "001" "  Result: MISMATCH - Versions are different!" # Bright Red
        fi
    done
done

gum style \
	--foreground "#04B575" --border-foreground "#04B575" --border double \
	--align center --width 60 --margin "1 2" --padding "1 2" \
	"Comparison Complete!"