#!/bin/bash
mkdir -p bin/

if odin build src/assembler -out:bin/bmasm -o:size 2>&1; then
    echo "Build succeeded"
else
    echo "Build failed"
fi
