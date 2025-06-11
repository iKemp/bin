#!/usr/bin/env bash

# Script to lookup openshift env vars that fit search term
# Usage: `oc_env_search.sh` or `oc_env_search.sh searchTerm`

# --- Helper Function for Dependency Checks ---
check_dependencies() {
    local -a commands_to_check=("$@") # Capture all arguments as an array
    local missing_commands=""

    for cmd in "${commands_to_check[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_commands+="$cmd " # Append missing command to the list
        fi
    done

    if [ -n "$missing_commands" ]; then
        echo "Error: The following required commands are not found in your PATH:"
        echo "       $missing_commands"
        echo "Please ensure they are installed and accessible."
        exit 1
    fi
}

# --- Main Script Logic ---
check_dependencies "oc" "gum" "yq"

SEARCH_TERM=$(gum input --placeholder "Enter your search term" --value "$1")
if [ -z "$SEARCH_TERM" ]; then
    echo "Enter a search term"
    exit 0
fi

# Apply optional filter pattern
FILTER_PATTERN=$(gum input --placeholder "Enter project name filter (e.g., 'dev-', 'team-a'):")
if [ -n "$FILTER_PATTERN" ]; then
    # Use -i for case-insensitive matching in grep
    SELECTED_PROJECTS=$(oc projects -q | grep -i "$FILTER_PATTERN" | gum choose --height 20 --no-limit --header "Choose projects matching '$FILTER_PATTERN'")
else
    # If no filter entered, show all (or exit, depending on desired behavior)
    SELECTED_PROJECTS=$(oc projects -q | gum choose --height 20 --no-limit --header "Choose all projects")
fi

# allow multi selection
#SELECTED_PROJECTS=$(oc projects -q | gum choose --height 20 --no-limit --header "Choose projects")

# Iterate over each selected project
if [ -n "$SELECTED_PROJECTS" ]; then # Check if anything was selected
    echo "--- Processing selections ---"
    while IFS= read -r SELECTED_PROJECT; do
        if [ -n "$SELECTED_PROJECT" ]; then # Ensure line is not empty (can happen if there are trailing newlines)
            echo "Processing project: $SELECTED_PROJECT"

            # find all deployments and deploymentConfigs
            DEPLOYMENTS=$(oc get deployments -o name -n $SELECTED_PROJECT; oc get deploymentconfigs -o name -n $SELECTED_PROJECT 2>/dev/null)
            while IFS= read -r SELECTED_DEPLOYMENT; do
                echo "Processing deployment: $SELECTED_DEPLOYMENT"
                
                ### !!! this has errors with config map references !!!
                #ENV_VARS=$(oc get $SELECTED_DEPLOYMENT -n $SELECTED_PROJECT -o yaml 2>/dev/null | yq '.spec.template.spec.containers[].env[] | select(.) | (.name + "=" + (.value // .valueFrom // ""))')
                
                # This yq command handles both direct 'value' and 'valueFrom' references
                # It will output in the format: NAME=VALUE or NAME=VALUE_FROM_CONFIGMAP_KEY_REF_environment/VI_PODOMAIN
                # And similarly for secretKeyRef
                RESOURCE_YAML=$(oc get $SELECTED_DEPLOYMENT -n $SELECTED_PROJECT -o yaml 2>/dev/null)
                ENV_VARS=$(echo "$RESOURCE_YAML" | yq -r '
                    .spec.template.spec.containers[].env[] | select(.) |
                    .name + "=" + (
                        if .value then .value
                        elif .valueFrom and .valueFrom.configMapKeyRef then
                        "VALUE_FROM_CONFIGMAP_KEY_REF_" + .valueFrom.configMapKeyRef.name + "/" + .valueFrom.configMapKeyRef.key
                        elif .valueFrom and .valueFrom.secretKeyRef then
                        "VALUE_FROM_SECRET_KEY_REF_" + .valueFrom.secretKeyRef.name + "/" + .valueFrom.secretKeyRef.key
                        # Add more valueFrom types here if needed (e.g., fieldRef, resourceFieldRef)
                        else
                        "UNKNOWN_VALUE_SOURCE"
                        end
                    )
                    ' 2>/dev/null)
                
                if [ -n "$ENV_VARS" ]; then
                    # Filter environment variables based on the search term (case-insensitive)
                    MATCHING_ENV_VARS=$(echo "$ENV_VARS" | grep -i "$SEARCH_TERM")

                    if [ -n "$MATCHING_ENV_VARS" ]; then
                        #echo "Matching env vars $MATCHING_ENV_VARS in deployment $SELECTED_DEPLOYMENT"
                        gum style --padding "1 5" --border double --border-foreground 212 "$MATCHING_ENV_VARS"
                    fi
                fi
            done <<< "$DEPLOYMENTS"

            # lookup configMaps
            # Get terminal width once (it's unlikely to change during the loop)
            TERMINAL_WIDTH=$(tput cols)
            # Calculate content width for gum style
            CM_CONTENT_WIDTH=$((TERMINAL_WIDTH - 12))

            CONFIG_MAPS=$(oc get cm -o name -n $SELECTED_PROJECT 2>/dev/null)        
            while IFS= read -r SELECTED_CM; do
                echo "Processing config map: $SELECTED_CM"
                RESOURCE_YAML=$(oc get $SELECTED_CM -n $SELECTED_PROJECT -o yaml 2>/dev/null)
                MATCHING_CM=$(echo "$RESOURCE_YAML" | yq '.data' | grep -i "$SEARCH_TERM") # restrict to data block; ommit last_applied annotation
                TRUNCATED_MATCHING_CM=$(echo "$MATCHING_CM" | cut -c 1-"$CM_CONTENT_WIDTH" ) # Limit to terminal width
                if [ -n "$MATCHING_CM" ]; then
                    gum style --padding "1 5" --border double --border-foreground 212 "$TRUNCATED_MATCHING_CM"
                fi
            done <<< "$CONFIG_MAPS"
            
        fi
    done <<< "$SELECTED_PROJECTS"
else
    echo "No projects were selected."
fi
