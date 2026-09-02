# Linux Fleet Package & Patch Management Lab

A home SRE lab for learning enterprise-style package management across multiple Linux distributions.

## Goals

This lab demonstrates:

- Ubuntu + Rocky Linux fleet management
- Ansible inventory and desired state
- Common package baseline
- Canary and production patch rings
- Rolling patch deployment
- Reboot detection
- Pre/post patch health checks
- Package version control
- Internal APT/RPM repository concepts
- Audit logging
- Failure testing

## Architecture

```text
                    Git
                     |
                     v
               sre-control01
                  Ansible
                     |
              +------+------+
              |             |
           Canary        Production
              |             |
        +-----+----+    +----+-----+
        |          |    |          |
     Ubuntu      Rocky Ubuntu     Rocky

                     ^
                     |
                   repo01
              +------+------+
              |             |
            APT Repo       RPM Repo
```

## VM Plan

| VM | OS | IP |
|---|---|---|
| sre-control01 | Ubuntu 24.04 | 192.168.56.10 |
| repo01 | Ubuntu 24.04 | 192.168.56.20 |
| ubu-canary01 | Ubuntu 24.04 | 192.168.56.31 |
| ubu-prod01 | Ubuntu 24.04 | 192.168.56.32 |
| rocky-canary01 | Rocky Linux 9 | 192.168.56.41 |
| rocky-prod01 | Rocky Linux 9 | 192.168.56.42 |

Use two VirtualBox NICs per VM:

1. NAT for Internet access
2. Host-Only network for fixed lab IPs

Recommended host-only subnet:

```text
192.168.56.0/24
```

## 1. Prepare the Control Node

On `sre-control01`:

```bash
sudo apt update
sudo apt install -y python3 python3-pip python3-venv git jq

python3 -m venv ~/venvs/ansible
source ~/venvs/ansible/bin/activate

pip install --upgrade pip
pip install -r requirements.txt
```

Verify:

```bash
ansible --version
```

## 2. Configure Managed Hosts

Create a `sysadmin` account on all managed nodes.

Ubuntu:

```bash
sudo adduser sysadmin
sudo usermod -aG sudo sysadmin
```

Rocky:

```bash
sudo useradd -m sysadmin
sudo passwd sysadmin
sudo usermod -aG wheel sysadmin
```

For this home lab only, add:

```text
sysadmin ALL=(ALL) NOPASSWD: ALL
```

using:

```bash
sudo visudo
```

## 3. Configure SSH Keys

On `sre-control01`:

```bash
ssh-keygen -t ed25519
```

Then:

```bash
ssh-copy-id sysadmin@192.168.56.31
ssh-copy-id sysadmin@192.168.56.32
ssh-copy-id sysadmin@192.168.56.41
ssh-copy-id sysadmin@192.168.56.42
```

## 4. Test Connectivity

```bash
./scripts/test-connectivity.sh
```

Or manually:

```bash
ansible-inventory --graph
ansible all -m ping
```

## 5. Apply Baseline

```bash
ansible-playbook playbooks/baseline.yml
```

Verify:

```bash
ansible all -a "curl -s http://127.0.0.1/health"
```

Expected output includes:

```text
OK - ubu-canary01
OK - ubu-prod01
OK - rocky-canary01
OK - rocky-prod01
```

## 6. Demonstrate Configuration Drift

Remove `jq` manually from one node.

Ubuntu example:

```bash
sudo apt remove -y jq
```

Then re-run:

```bash
ansible-playbook playbooks/baseline.yml
```

Ansible should restore the package.

## 7. Audit Pending Updates

```bash
./scripts/run-audit.sh
```

Reports are saved under:

```text
reports/
```

## 8. Patch Canary Ring

```bash
./scripts/patch-canary.sh
```

Equivalent command:

```bash
ansible-playbook playbooks/patch.yml --limit canary
```

Only these hosts should be patched:

```text
ubu-canary01
rocky-canary01
```

## 9. Verify Canary

```bash
ansible canary -a "uptime"
ansible canary -a "curl -s http://127.0.0.1/health"
```

Do not promote to production unless Canary is healthy.

## 10. Patch Production

```bash
./scripts/patch-production.sh
```

Equivalent:

```bash
ansible-playbook playbooks/patch.yml --limit production
```

`serial: 1` makes the playbook patch one server at a time.

## 11. Package Version Policy

Run:

```bash
ansible-playbook playbooks/version-policy.yml
```

This demonstrates:

- Ubuntu `apt-mark hold`
- Rocky `dnf versionlock`

## 12. Internal Repository

The lab reserves:

```text
repo01 = 192.168.56.20
```

Recommended later implementation:

### Ubuntu

Use Aptly:

```text
Upstream
  |
  v
Mirror
  |
  v
Snapshot
  |
  v
Approved Snapshot
  |
  v
Published APT Repo
```

### Rocky

Start with:

```text
dnf download
createrepo_c
nginx
```

Then advance to:

```text
reposync
Pulp
```

Client repository configuration is demonstrated in:

```text
playbooks/repo-config.yml
```

## Recommended Workflow

```text
Package Audit
     |
     v
Canary
     |
     v
Pre-health check
     |
     v
Patch
     |
     v
Reboot if required
     |
     v
Post-health check
     |
     v
Approve
     |
     v
Production
```

## Failure Tests

See:

```text
docs/failure-tests.md
```

The important lesson is not just how to patch successfully. A production-grade system must also stop safely when validation fails.

## Repository Structure

```text
linux-patch-lab/
├── ansible.cfg
├── inventory/
│   └── hosts.yml
├── group_vars/
│   ├── ubuntu.yml
│   └── rocky.yml
├── playbooks/
│   ├── baseline.yml
│   ├── audit.yml
│   ├── patch.yml
│   ├── repo-config.yml
│   └── version-policy.yml
├── roles/
├── reports/
├── scripts/
├── docs/
├── requirements.txt
└── README.md
```

## Push to GitHub

After extracting the ZIP:

```bash
cd linux-patch-lab

git init
git add .
git commit -m "Initial Linux fleet package management lab"
git branch -M main
git remote add origin https://github.com/YOUR-USERNAME/linux-patch-lab.git
git push -u origin main
```

## Future Enhancements

Recommended progression:

1. Refactor playbooks into reusable Ansible roles
2. Add Aptly repository snapshots
3. Add Rocky repository mirroring
4. Add AWX
5. Add Pulp
6. Integrate Zabbix health checks
7. Add CVE/security patch reporting
8. Add GitHub Actions validation
9. Generate HTML/JSON fleet patch reports
10. Add an AI SRE layer for proactive analysis and remediation recommendations
