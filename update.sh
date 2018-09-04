#!/usr/bin/env bash

# Fail if any command fails
set -e
set -o pipefail

dconf dump /apps/guake/ > linux-only/dconf-guake-dump.txt
