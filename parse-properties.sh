#!/usr/bin/env bash

declare -A properties

# Read with:
# IFS (Field Separator) =
# -d (Record separator) newline
# first field before separator as k (key)
# second field after separator and reminder of record as v (value)
while IFS='=' read -d $'\n' -r k v; do
  # Skip lines starting with sharp
  # or lines containing only space or empty lines
  [[ "$k" =~ ^([[:space:]]*|[[:space:]]*#.*)$ ]] && continue

  # modify key to legit env var
  key=${k//[^A-Za-z0-9]/_}
  key=${key^^}

  # Store key value into assoc array
  properties[$key]="$v"
  # stdin the properties file
#done < /home/ingo/devel/viessmann/projects/ecommerce/oci-punchout/src/main/resources/application.properties
#done < file.properties
done < $1

# display the array for testing
#typeset -p properties

echo 'env:'
for i in "${!properties[@]}"
do
  echo "  - name: $i"
  echo "    value: ${properties[$i]}"
done
