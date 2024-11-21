#!/bin/bash

rm -rf library/src/main/resources/rawfile/whiteboard
mkdir -p library/src/main/resources/rawfile/whiteboard
cp -R ../whiteboard-bridge/build/* library/src/main/resources/rawfile/whiteboard