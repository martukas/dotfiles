#!/bin/bash

# Fail if any command fails
set -e
set -o pipefail

git submodule update --remote
