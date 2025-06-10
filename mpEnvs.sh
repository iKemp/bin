#!/usr/bin/env bash

# Check if an argument is provided
if [ -z "$1" ]; then
  echo "Usage: $0 <application_key>"
  exit 1
fi

input_key="$1"

echo "$input_key" \
    | cut -d ':' -f1 \
    | cut -d '=' -f1 \
    | sed -E 's/[^[:alnum:]_]/_/g' \
    | awk -F '=' '{print toupper($1)}'