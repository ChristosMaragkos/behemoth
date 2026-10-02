#!/bin/bash
mkdir -p bin/

if odin build src/tools/png2bin -out:bin/png2bin -o:size 2>&1; then
    echo "Build succeeded"
else
    echo "Build failed"
fi
