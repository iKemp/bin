#!/usr/bin/env bash

# Source the utility functions
source "$(dirname "$0")/../lib/bash/utils.sh"

# --- Main Script Logic ---
check_dependencies "oc" "gum"

# Function to get commit hash from an image stream tag using a specific context
get_commit_hash() {
  local KUBE_CONTEXT=$1
  local IMAGE_STREAM_TAG=$2

  # Using a temporary variable to capture output before grep, to avoid pipefail issues
  # if 'describe istag' fails or finds no output.
  local DESCRIBE_OUTPUT
  if ! DESCRIBE_OUTPUT=$(oc --context="${KUBE_CONTEXT}" describe istag "${IMAGE_STREAM_TAG}" 2>/dev/null); then
    # If oc describe fails (e.g., istag not found), return empty string.
    # This prevents pipefail from exiting the script if grep receives no input.
    echo ""
    return 0
  fi

  # Now, grep and awk on the captured output.
  echo "$DESCRIBE_OUTPUT" | grep -i 'Image:' | awk '{print $NF}' | rev | cut -d: -f1 | rev || true
  # Added '|| true' to the end of the pipeline. This ensures that if grep doesn't find
  # 'Image:', the pipeline still succeeds (returns 0), preventing 'set -e' from exiting.
}

# --- Main Script ---

gum style \
	--foreground "#04B575" --border-foreground "#04B575" --border double \
	--align center --width 60 --margin "1 2" --padding "1 2" \
	"OpenShift ImageStream Version Comparison" "Across Contexts (All ImageStreams)"

echo ""

# Get all available contexts
ALL_CONTEXTS=$(oc config get-contexts -o name || true) # Added || true to prevent 'set -e' if no contexts found
if [ -z "$ALL_CONTEXTS" ]; then
    gum style --foreground "204" "No OpenShift contexts found in your kubeconfig. Please ensure you are logged in to some clusters."
    exit 1
fi

gum style --foreground "#04B575" "Select Source Cluster Context:"
SOURCE_CONTEXT=$(echo "$ALL_CONTEXTS" | gum choose --limit=1)
if [ -z "$SOURCE_CONTEXT" ]; then
    gum style --foreground "204" "Source context selection cancelled. Exiting."
    exit 1
fi

gum style --foreground "#04B575" "Select Target Cluster Context:"
TARGET_CONTEXT=$(echo "$ALL_CONTEXTS" | grep -v "$SOURCE_CONTEXT" | gum choose --limit=1) # Exclude the already selected source context
if [ -z "$TARGET_CONTEXT" ]; then
    gum style --foreground "204" "Target context selection cancelled. Exiting."
    exit 1
fi

gum style --foreground "204" "Selected Source: ${SOURCE_CONTEXT}"
gum style --foreground "204" "Selected Target: ${TARGET_CONTEXT}"

# Determine the project for the source context to get ImageStreams from
SOURCE_PROJECT=$(oc --context="${SOURCE_CONTEXT}" project -q 2>/dev/null || true) # Allow project command to fail gracefully
if [ -z "$SOURCE_PROJECT" ]; then
    gum style --foreground "204" "Could not determine the current project for context '${SOURCE_CONTEXT}'. Please ensure a project is set for this context."
    exit 1
fi
gum style --foreground "240" "ImageStreams will be fetched from the current project of the source context: ${SOURCE_PROJECT}"

# Discover all ImageStreams in the source context's current project
gum style --foreground "#04B575" "Discovering ImageStreams in context '${SOURCE_CONTEXT}' (project: '${SOURCE_PROJECT}')..."
IMAGE_STREAMS=$(oc --context="${SOURCE_CONTEXT}" get is -o custom-columns=":metadata.name" --no-headers 2>/dev/null | grep -v 'openshift' || true)
# Added || true to grep to prevent pipefail if no "openshift" lines are found

if [ -z "$IMAGE_STREAMS" ]; then
    gum style --foreground "204" "No user-defined ImageStreams found in project '${SOURCE_PROJECT}' for context '${SOURCE_CONTEXT}'. Exiting."
    exit 1
fi

# Image tags to compare
IMAGE_TAGS=("latest" "stage" "prod")

# Calculate number of ImageStreams outside gum style for robustness
num_imagestreams=$(echo "$IMAGE_STREAMS" | wc -l | tr -d '[:space:]')
#gum style --foreground "#04B575" \
#	--width 70 --margin "1 0" --padding "0 1" \
#	"--- Starting comparison for ${num_imagestreams} ImageStreams ---"

echo "$IMAGE_STREAMS" | while IFS= read -r IS_NAME; do
    gum style --foreground "04B575" --margin "1 0" --padding "0 1" "Comparing ImageStream: ${IS_NAME}"

    for TAG in "${IMAGE_TAGS[@]}"; do
        FULL_IMAGE_STREAM_TAG="${IS_NAME}:${TAG}"

        gum style --foreground "240" "  --- Checking tag: ${TAG} ---"

        # Fetch commit hashes
        SOURCE_COMMIT=$(get_commit_hash "$SOURCE_CONTEXT" "$FULL_IMAGE_STREAM_TAG")
        TARGET_COMMIT=$(get_commit_hash "$TARGET_CONTEXT" "$FULL_IMAGE_STREAM_TAG")

        gum style --foreground "240" "  Source Cluster (Context: $SOURCE_CONTEXT): $( [ -n "$SOURCE_COMMIT" ] && echo "$SOURCE_COMMIT" || echo "Not Found" )"
        gum style --foreground "240" "  Target Cluster (Context: $TARGET_CONTEXT): $( [ -n "$TARGET_COMMIT" ] && echo "$TARGET_COMMIT" || echo "Not Found" )"

        if [[ -z "$SOURCE_COMMIT" && -z "$TARGET_COMMIT" ]]; then
            gum style --foreground "240" "  Result: Neither cluster has this tag."
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