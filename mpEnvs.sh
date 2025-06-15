#!/usr/bin/env bash

# Function to transform a single key
transform_key() {
    local key="$1"
    echo "$key" \
        | cut -d ':' -f1 \
        | cut -d '=' -f1 \
        | sed -E 's/[^[:alnum:]_]/_/g' \
        | awk '{print toupper($1)}' # No need for -F '=' here as cut already handled it
}

# Check the number of arguments
if [ -z "$1" ]; then
    echo "Usage: $0 <application_key> | <properties_file>"
    echo "  <application_key>: A single key to transform (e.g., 'my.app.key')"
    echo "  <properties_file>: Path to a .properties file to transform all keys"
    exit 1
fi

input="$1"

# Check if the input is a file
if [ -f "$input" ]; then
    echo "Processing keys from file: $input"
    grep -vE '^\s*$|^#' "$input" \
        | while IFS= read -r line; do
            transform_key "$line"
        done
else
    echo "Processing single key: $input"
    transform_key "$input"
fi