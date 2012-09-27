#!/bin/sh

# This should be run from the root project directory

for file in doc_src/*; do
    working_dir="$(head -1 "$file" | awk '{ print $2 }')"
    python tools/place_code.py "$working_dir" "$file" -o "${file#doc_src/}"
done
