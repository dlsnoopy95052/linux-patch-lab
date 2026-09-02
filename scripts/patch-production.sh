#!/usr/bin/env bash
set -euo pipefail

ansible-playbook playbooks/patch.yml --limit production
