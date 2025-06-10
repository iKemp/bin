#!/usr/bin/env bash

# Script to lookup openshift env vars that fit search term

# Preconditions
if ! command -v oc &> /dev/null
then
    echo "Error: 'oc' command not found. Please ensure OpenShift CLI is installed and in your PATH."
    exit 1
fi
if ! command -v gum &> /dev/null
then
    echo "Error: 'gum' command not found. Please ensure gum is installed and in your PATH."
    exit 1
fi
if ! command -v yq &> /dev/null
then
    echo "Error: 'yq' command not found. Please ensure gum is installed and in your PATH."
    exit 1
fi


SEARCH_TERM=$(gum input --placeholder "Enter your search term")
if [ -z "$SEARCH_TERM" ]; then
    echo "Enter a search term"
    exit 0
fi

# allow multi selection
SELECTED_PROJECTS=$(oc projects -q | gum choose --height 40 --no-limit --header "Choose projects")
#echo "You selected the following projects:"
#echo "$SELECTED_PROJECTS" # This will print each on a new line

# Iterate over each selected project
if [ -n "$SELECTED_PROJECTS" ]; then # Check if anything was selected
    echo "--- Processing selections ---"
    while IFS= read -r SELECTED_PROJECT; do
        if [ -n "$SELECTED_PROJECT" ]; then # Ensure line is not empty (can happen if there are trailing newlines)
            echo "Processing project: $SELECTED_PROJECT"

            # find all deployments and deployment configs
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
                
            done  <<< "$DEPLOYMENTS"
            
        fi
    done <<< "$SELECTED_PROJECTS"
else
    echo "No projects were selected."
fi
