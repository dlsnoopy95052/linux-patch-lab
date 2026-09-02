#!/usr/bin/env bash
set -euo pipefail

ansible-inventory --graph
ansible all -m ping
ansible all -m setup -a "filter=ansible_distribution*"
