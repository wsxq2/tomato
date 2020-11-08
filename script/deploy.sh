#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

set -x

scp -r -P26635 gfw/ wsxq21.55555.io:/root/
scp -r -P26635 gfw/ 64.64.228.229:/root/
