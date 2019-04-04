#!/usr/bin/env bash

[[ -n "$DEBUG" || -n "$ANSIBLE_DEBUG" ]] && set -x

set -euo pipefail

export ANSIBLE_CONFIG=ansible.cfg
export FOREMAN_PROTOCOL="${FOREMAN_PROTOCOL:-http}"
export FOREMAN_HOST="${FOREMAN_HOST:-localhost}"
export FOREMAN_PORT="${FOREMAN_PORT:-8080}"
export FOREMAN_USER="${FOREMAN_USER:-admin}"
export FOREMAN_PASS="${FOREMAN_PASS:-changeme}"
export HOST_UNDER_TEST="${HOST_UNDER_TEST:-sat-snap-rhel6.example.com}"
FOREMAN_CONFIG=test-config.foreman.yaml

# Set inventory caching environment variables to populate a jsonfile cache
export ANSIBLE_INVENTORY_CACHE=True
export ANSIBLE_INVENTORY_CACHE_PLUGIN=jsonfile
export ANSIBLE_INVENTORY_CACHE_CONNECTION=./foreman_cache

# flag for checking whether cleanup has already fired
_is_clean=

function _cleanup() {
    [[ -n "$_is_clean" ]] && return  # don't double-clean
    echo Cleanup: removing $ANSIBLE_CONFIG $FOREMAN_CONFIG...
    rm -vf "$ANSIBLE_CONFIG" "$FOREMAN_CONFIG"
    rm -rfv "$ANSIBLE_INVENTORY_CACHE_CONNECTION"
    unset ANSIBLE_CONFIG
    unset FOREMAN_PROTOCOL
    unset FOREMAN_HOST
    unset FOREMAN_PORT
    unset FOREMAN_USER
    unset FOREMAN_PASS
    unset FOREMAN_CONFIG
    unset HOST_UNDER_TEST
    _is_clean=1
}
trap _cleanup INT TERM EXIT

cat > "$ANSIBLE_CONFIG" <<ANSIBLE_YAML
[defaults]
inventory = $FOREMAN_CONFIG
callback_whitelist = foreman

[inventory]
enable_plugins = foreman

[callback_foreman]
url = ${FOREMAN_PROTOCOL}://${FOREMAN_HOST}:${FOREMAN_PORT}
ssl_cert = /dev/null
ssl_key = /dev/null
verify_certs = False
ANSIBLE_YAML

cat > "$FOREMAN_CONFIG" <<FOREMAN_YAML
plugin: foreman
url: ${FOREMAN_PROTOCOL}://${FOREMAN_HOST}:${FOREMAN_PORT}
user: ${FOREMAN_USER}
password: ${FOREMAN_PASS}
validate_certs: False
FOREMAN_YAML

ansible-playbook set_foreman_facts.yml --connection=local "$@"
ansible-playbook test_foreman_fact_collection.yml --connection=local "$@"
