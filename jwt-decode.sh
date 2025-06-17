#!/usr/bin/env bash

# Source the utility functions
source "$(dirname "$0")/../lib/bash/utils.sh"

check_dependencies "jq" "gum"

# --- Function to handle input parsing ---
# This function determines if the input is a file path or a direct token.
# It returns the actual token content.
get_token_content() {
    local raw_input="$1"
    local token_content=""

    if [ -z "$raw_input" ]; then
        # No initial argument, prompt user for input
        gum style \
            --padding "1 2" \
            --border double \
            --border-foreground 212 \
            "Please paste your JWT token or path to file containing token:"

        raw_input=$(gum input \
            --char-limit=0 \
            --placeholder "Paste JWT token or file path here...")

        if [ -z "$raw_input" ]; then
            echo "No input provided. Exiting." >&2 # Redirect error to stderr
            exit 1
        fi
    fi

    # Now, check if the raw_input (from argument or gum input) is a file path
    if [ -f "$raw_input" ]; then
        token_content=$(cat "$raw_input")
        if [ -z "$token_content" ]; then
            echo "Error: File '$raw_input' is empty or could not be read." >&2
            exit 1
        fi
    else
        # If not a file, treat it as a direct token
        token_content="$raw_input"
    fi

    echo "$token_content" # Output the extracted token content
}

# --- Function to decode JWT token ---
# Accepts the JWT token string as an argument
function jwt_decode(){
    local token="$1"
    # Extract the payload part (second segment) and base64 decode, then parse as JSON
    jq -R 'split(".") | .[1] | @base64d | fromjson' <<< "$token" 2>/dev/null
}

# --- Main Script Logic ---

# Get the token content using the new function
# Pass the first argument of the script to the function, if it exists
TOKEN_INPUT=$(get_token_content "$1")

# Ensure the token has at least two dots (for header.payload.signature structure)
if ! echo "$TOKEN_INPUT" | grep -q '\.*\.'; then
    echo "Error: Invalid JWT token format. A JWT token typically has two dots (e.g., header.payload.signature)."
    exit 1
fi

# Decode the JWT token
DECODED_PAYLOAD=$(jwt_decode "$TOKEN_INPUT")

# Check if decoding was successful (jq will return non-zero if not valid JSON/JWT)
if [ $? -ne 0 ] || [ -z "$DECODED_PAYLOAD" ]; then
    echo "Error: Failed to decode JWT token. Please ensure it's a valid JWT token."
    echo "Attempted payload:"
    echo "$DECODED_PAYLOAD" # Show what was captured, might be an error message
    exit 1
fi

# 2) Display the output with gum pager
echo "--- Decoded JWT Payload ---"
echo "$DECODED_PAYLOAD" | gum pager

echo "--- Decoding Complete ---"
