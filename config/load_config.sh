#!/usr/bin/env bash
# Resolve and source the pipeline config, wherever a stage script is invoked
# from. Override the location with PIPELINE_CONFIG=/some/other.env.
#
# Usage, from any stage script:
#   source "$(dirname "${BASH_SOURCE[0]}")/../../config/load_config.sh"

_repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PIPELINE_CONFIG="${PIPELINE_CONFIG:-${_repo_root}/config/pipeline.env}"

if [ ! -f "$PIPELINE_CONFIG" ]; then
    echo "ERROR: no config found at $PIPELINE_CONFIG" >&2
    echo "       cp config/pipeline.env.example config/pipeline.env && edit it" >&2
    exit 1
fi

# shellcheck disable=SC1090
source "$PIPELINE_CONFIG"

# Fail loudly on unset required values rather than silently writing to ./
for _v in SLURM_PARTITION WORK_DIR; do
    if [ -z "${!_v}" ]; then
        echo "ERROR: $_v is unset in $PIPELINE_CONFIG" >&2
        exit 1
    fi
done
unset _v _repo_root
