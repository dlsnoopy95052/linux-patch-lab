#!/usr/bin/env bash
set -euo pipefail

mkdir -p reports
STAMP="$(date +%F-%H%M%S)"
ansible-playbook playbooks/audit.yml | tee "reports/audit-${STAMP}.log"
