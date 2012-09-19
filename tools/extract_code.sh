#!/bin/sh

# This should be run from the root project directory

for file in doc_src/*; do
    python tools/place_code.py src/echo_server "$file" -o "${file#doc_src/}"
done
