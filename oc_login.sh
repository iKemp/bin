#!/usr/bin/env bash

# Script to log in to OpenShift based on environment
# Usage: ./oc_login.sh

# Preconditions
# Check if oc command exists
if ! command -v oc &> /dev/null
then
    echo "Error: 'oc' command not found. Please ensure OpenShift CLI is installed and in your PATH."
    exit 1
fi
# Check if gum command exists https://github.com/charmbracelet/gum
if ! command -v gum &> /dev/null
then
    echo "Error: 'gum' command not found. Please ensure gum is installed and in your PATH."
    exit 1
fi

echo "Pick a cluster to login..."
CLUSTER_ENV=$(gum choose "dev-01" "dev-02" "prod-01" "prod-02")
echo $CLUSTER_ENV

case "$CLUSTER_ENV" in
    dev-01)
        OCP_SERVER="https://api.oscp4-dev-01.viessmann.net:6443 --insecure-skip-tls-verify=true" 
        ;;
    prod-01)
        OCP_SERVER="https://api.oscp4-prod-01.viessmann.net:6443 --insecure-skip-tls-verify=true" 
        # For production, always use proper TLS verification.
        # --certificate-authority=<path/to/prod_ca.crt> if you have a custom CA
        ;;
    dev-02)
        OCP_SERVER="https://api.oscp4-dev-02.viessmann.net:6443 --insecure-skip-tls-verify=true" 
        ;;
    prod-02)
        OCP_SERVER="https://api.oscp4-prod-02.viessmann.net:6443 --insecure-skip-tls-verify=true" 
        # For production, always use proper TLS verification.
        # --certificate-authority=<path/to/prod_ca.crt> if you have a custom CA
        ;;
    *)
        echo "Error: Invalid cluster environment '$CLUSTER_ENV'."
        echo "Please use 'dev' or 'prod'."
        exit 1
        ;;
esac

USER=kmpi
PASSWORD=$(gum input --password --placeholder "Enter your password")
gum spin --spinner meter --title "Attempting to log in to OpenShift '$CLUSTER_ENV' cluster at: $OCP_SERVER" --show-output -- oc login $OCP_SERVER -u $USER -p $PASSWORD
