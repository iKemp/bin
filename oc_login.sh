#!/usr/bin/env bash

# Script to log in to OpenShift based on environment
# Usage: ./oc_login.sh

# Source the utility functions
source "$(dirname "$0")/../lib/bash/utils.sh"

# --- Helper Function to Get Current Login Info ---
get_current_cluster_info() {
    # Attempt to get the current user.
    # If successful, oc whoami outputs the user.
    # If unsuccessful (logged out, token expired), it outputs the forbidden error to stderr
    # and returns a non-zero exit code.
    CURRENT_USER=$(oc whoami 2>/dev/null) # Suppress stderr to keep terminal clean

    if [ $? -eq 0 ] && [ -n "$CURRENT_USER" ] && [ "$CURRENT_USER" != "system:anonymous" ]; then
        # If oc whoami succeeded and returned a user (not system:anonymous)
        # Then, get the server URL (this part is safe as it's just reading kubeconfig)
        CURRENT_SERVER=$(oc whoami --show-server 2>/dev/null)
        if [ $? -eq 0 ] && [ -n "$CURRENT_SERVER" ]; then
            echo "$CURRENT_SERVER"
        else
            # Fallback, theoretically this path should not be hit if oc whoami succeeds
            echo ""
        fi
    else
        # Not logged in, or token invalid, or only anonymous access
        echo ""
    fi
}

# --- Define Menu Entry Variables ---
readonly MENU_DEV_01="Dev 01 Cluster (deprecated)"
readonly MENU_DEV_02="Dev 02 Cluster"
readonly MENU_PROD_01="Prod 01 Cluster (deprecated)"
readonly MENU_PROD_02="Prod 02 Cluster"

# --- Main Menu Function ---
main_menu() {
    gum choose --header="Pick a cluster to login..." \
        "$MENU_DEV_02" \
        "$MENU_PROD_02" \
        "$MENU_DEV_01" \
        "$MENU_PROD_01"
}

# --- Main Script Logic ---
check_dependencies "oc" "gum"

echo "--- OpenShift Cluster Login ---"

# precheck for existing login
CURRENTLY_LOGGED_IN_SERVER=$(get_current_cluster_info)
if [ -n "$CURRENTLY_LOGGED_IN_SERVER" ]; then
    echo "You are currently logged into: $CURRENTLY_LOGGED_IN_SERVER"
    gum confirm --default=false "Do you want to switch to a different cluster?"
    if [ $? -eq 0 ]; then # $? is 0 if user confirms (Yes), non-zero if No or Esc
        echo "Proceeding to select a new cluster..."
    else
        echo "Keeping current login. Exiting."
        exit 0
    fi
else
    echo "You are not currently logged into any OpenShift cluster."
    echo "Please select a cluster to log in."
fi


CLUSTER_ENV=$(main_menu)
echo $CLUSTER_ENV

case "$CLUSTER_ENV" in
    "$MENU_DEV_01")
        OCP_SERVER="https://api.oscp4-dev-01.viessmann.net:6443 --insecure-skip-tls-verify=true" 
        ;;
    "$MENU_PROD_01")
        OCP_SERVER="https://api.oscp4-prod-01.viessmann.net:6443 --insecure-skip-tls-verify=true" 
        # For production, always use proper TLS verification.
        # --certificate-authority=<path/to/prod_ca.crt> if you have a custom CA
        ;;
    "$MENU_DEV_02")
        OCP_SERVER="https://api.oscp4-dev-02.viessmann.net:6443 --insecure-skip-tls-verify=true" 
        ;;
    "$MENU_PROD_02")
        OCP_SERVER="https://api.oscp4-prod-02.viessmann.net:6443 --insecure-skip-tls-verify=true" 
        # For production, always use proper TLS verification.
        # --certificate-authority=<path/to/prod_ca.crt> if you have a custom CA
        ;;
    *)
        echo "Error: Invalid cluster environment '$CLUSTER_ENV'."
        echo "Please select an environment."
        exit 1
        ;;
esac

USER=kmpi
PASSWORD=$(gum input --password --placeholder "Enter your password")
gum spin --spinner meter --title "Attempting to log in to OpenShift '$CLUSTER_ENV' cluster at: $OCP_SERVER" --show-output -- oc login $OCP_SERVER -u $USER -p $PASSWORD
