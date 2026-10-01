#!/bin/bash
mkdir -p bin/

if odin build src/frontend/raylib -out:bin/behemoth -o:speed 2>&1; then
    echo "Build succeeded"
else
    echo "Build failed"
fi
