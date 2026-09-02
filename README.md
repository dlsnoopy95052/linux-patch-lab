# Linux Fleet Package & Patch Management Lab

A home SRE lab for learning enterprise-style Linux package management, patching, canary deployment, health validation, and internal repository concepts across Ubuntu and Rocky Linux.

The lab can be built automatically with **Vagrant + VirtualBox**. Ansible is then used to manage package installation and maintenance across the Linux fleet.

---

## Goals

This lab demonstrates:

- Ubuntu + Rocky Linux fleet management
- Infrastructure-as-Code VM creation with Vagrant
- Ansible inventory and desired state
- Common package baseline management
- Canary and production patch rings
- Rolling patch deployment
- Reboot detection
- Pre/post patch health checks
- Package version control
- Internal APT/RPM repository concepts
- Audit logging
- Failure testing
- A foundation for later AWX, Pulp, Zabbix, CVE, and AI-SRE automation

---

# Lab Architecture

```text
Windows Host
    |
    +-- VirtualBox
    |
    +-- Vagrant
          |
          +-- sre-control01
          |     Ubuntu 24.04
          |     192.168.56.10
          |
          |     Ansible Control
          |     Git workspace
          |     Nginx
          |     Aptly
          |     RPM repo tools
          |
          +-- ubu-canary01
          |     Ubuntu 24.04
          |     192.168.56.31
          |
          +-- ubu-prod01
          |     Ubuntu 24.04
          |     192.168.56.32
          |
          +-- rocky-canary01
          |     Rocky Linux 9
          |     192.168.56.41
          |
          +-- rocky-prod01
                Rocky Linux 9
                192.168.56.42
```

Logical management flow:

```text
                       Git
                        |
                        v
                  sre-control01
                     Ansible
                        |
                +-------+-------+
                |               |
             CANARY         PRODUCTION
                |               |
          +-----+-----+     +---+------+
          |           |     |          |
       Ubuntu       Rocky  Ubuntu     Rocky

                        ^
                        |
                 Internal Repositories
                  hosted on control01
                  +------+------+
                  |             |
                APT Repo      RPM Repo
```

The home-lab version intentionally combines the **Ansible control node** and **repository server** into one VM.

In a larger production environment these would normally be separated.

---

# VM Plan

| VM | OS | IP | Role | RAM | CPU |
|---|---|---|---|---:|---:|
| `sre-control01` | Ubuntu 24.04 | `192.168.56.10` | Ansible + repository tools | 4 GB | 2 |
| `ubu-canary01` | Ubuntu 24.04 | `192.168.56.31` | Canary | 2 GB | 2 |
| `ubu-prod01` | Ubuntu 24.04 | `192.168.56.32` | Production | 2 GB | 2 |
| `rocky-canary01` | Rocky Linux 9 | `192.168.56.41` | Canary | 2 GB | 2 |
| `rocky-prod01` | Rocky Linux 9 | `192.168.56.42` | Production | 2 GB | 2 |

Approximate total memory if all five VMs run at once:

```text
12 GB
```

Each VM normally has:

1. NAT interface for Internet access
2. VirtualBox private/host-only interface for the lab network

Lab subnet:

```text
192.168.56.0/24
```

---

# Quick Start with Vagrant

## Prerequisites

Install on the Windows host:

- VirtualBox
- Vagrant
- Git

Verify:

```powershell
VBoxManage --version
vagrant --version
git --version
```

---

## 1. Clone or Download This Repository

Example:

```powershell
git clone https://github.com/YOUR-USERNAME/linux-patch-lab.git
cd linux-patch-lab
```

The repository root should contain:

```text
linux-patch-lab/
├── Vagrantfile
├── README.md
├── ansible.cfg
├── inventory/
├── group_vars/
├── playbooks/
├── roles/
├── scripts/
├── docs/
└── requirements.txt
```

---

## 2. Create the Control VM First

Run:

```powershell
vagrant up sre-control01
```

The Vagrant provisioning process automatically installs:

```text
Python
Ansible
Git
jq
curl
Nginx
GnuPG
Aptly
createrepo-c
```

It also automatically creates an Ansible SSH key.

---

## 3. Create the Remaining VMs

After the control node is ready:

```powershell
vagrant up
```

Vagrant creates:

```text
ubu-canary01
ubu-prod01
rocky-canary01
rocky-prod01
```

Managed nodes automatically receive:

```text
sysadmin account
passwordless sudo for the lab
Python
Ansible control-node public SSH key
```

The managed nodes therefore do not require manual `ssh-copy-id`.

---

## 4. Check VM Status

```powershell
vagrant status
```

Expected:

```text
sre-control01      running
ubu-canary01       running
ubu-prod01         running
rocky-canary01     running
rocky-prod01       running
```

You can also view them in the VirtualBox GUI.

---

## 5. SSH to the Control Node

```powershell
vagrant ssh sre-control01
```

Activate the Ansible virtual environment:

```bash
source ~/venvs/ansible/bin/activate
```

Move to the shared Git project:

```bash
cd /vagrant
```

Check Ansible:

```bash
ansible --version
```

---

## 6. Check the Inventory

```bash
ansible-inventory --graph
```

You should see groups similar to:

```text
@all:
  |--@canary:
  |  |--ubu-canary01
  |  |--rocky-canary01
  |
  |--@production:
  |  |--ubu-prod01
  |  |--rocky-prod01
  |
  |--@ubuntu:
  |
  |--@rocky:
```

---

## 7. Test Ansible Connectivity

```bash
ansible all -m ping
```

Expected for each managed server:

```text
SUCCESS => {
    "changed": false,
    "ping": "pong"
}
```

You can also run:

```bash
./scripts/test-connectivity.sh
```

---

# Common Vagrant Commands

## Start Everything

```powershell
vagrant up
```

## Start One VM

```powershell
vagrant up ubu-canary01
```

## SSH to a VM

```powershell
vagrant ssh ubu-canary01
```

## Show Status

```powershell
vagrant status
```

## Stop All VMs

```powershell
vagrant halt
```

## Stop One VM

```powershell
vagrant halt rocky-prod01
```

## Restart a VM

```powershell
vagrant reload ubu-canary01
```

## Re-run Provisioning

```powershell
vagrant provision ubu-canary01
```

or:

```powershell
vagrant reload --provision ubu-canary01
```

## Destroy All Lab VMs

```powershell
vagrant destroy -f
```

This deletes the VMs, but **does not delete the Git project**.

You can rebuild the complete environment later with:

```powershell
vagrant up sre-control01
vagrant up
```

This is one of the main benefits of Infrastructure as Code.

---

# Why Vagrant Is Used

Vagrant manages the VM lifecycle:

```text
Vagrantfile
    |
    v
VirtualBox
    |
    +-- Create VM
    +-- CPU
    +-- Memory
    +-- Networking
    +-- Hostname
    +-- Base OS
    +-- Initial provisioning
```

Ansible manages what happens **inside** the Linux servers:

```text
Ansible
   |
   +-- packages
   +-- configuration
   +-- services
   +-- patching
   +-- reboot
   +-- health checks
```

The separation is:

```text
Vagrant = build the servers

Ansible = manage the servers
```

---

# Vagrant Box Images

The current Vagrantfile uses:

```text
Ubuntu 24.04:
bento/ubuntu-24.04

Rocky Linux 9:
bento/rockylinux-9
```

Vagrant downloads these boxes automatically the first time they are needed.

The first `vagrant up` therefore takes longer than later builds.

---

# Shared Folder Design

Only `sre-control01` uses the repository shared folder:

```text
Windows project directory
        |
        v
/vagrant
```

This means when you edit:

```text
README.md
inventory/
playbooks/
group_vars/
```

on Windows, those changes are immediately visible inside:

```text
sre-control01:/vagrant
```

The Rocky and Ubuntu managed nodes do **not** need the project shared folder.

This is intentional because kernel patching and VirtualBox Guest Additions can sometimes affect shared-folder behavior.

Ansible communicates with managed nodes over SSH instead.

---

# Manual VM Build Option

Vagrant is the recommended way to build this lab.

However, you can also create the five VMs manually in VirtualBox.

If you build manually, use:

```text
sre-control01      192.168.56.10
ubu-canary01       192.168.56.31
ubu-prod01         192.168.56.32
rocky-canary01     192.168.56.41
rocky-prod01       192.168.56.42
```

For manual builds, create a `sysadmin` account on every managed node.

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

For this home lab only:

```text
sysadmin ALL=(ALL) NOPASSWD: ALL
```

Add it with:

```bash
sudo visudo
```

Then generate an SSH key on `sre-control01`:

```bash
ssh-keygen -t ed25519
```

Copy it:

```bash
ssh-copy-id sysadmin@192.168.56.31
ssh-copy-id sysadmin@192.168.56.32
ssh-copy-id sysadmin@192.168.56.41
ssh-copy-id sysadmin@192.168.56.42
```

If you use Vagrant provisioning, these manual account and SSH-key steps are not required.

---

# 1. Apply the Linux Baseline

From `sre-control01`:

```bash
source ~/venvs/ansible/bin/activate
cd /vagrant
```

Run:

```bash
ansible-playbook playbooks/baseline.yml
```

The baseline installs common packages and web services.

Ubuntu uses packages such as:

```text
curl
vim
jq
chrony
rsyslog
needrestart
nginx
```

Rocky uses:

```text
curl
vim-enhanced
jq
chrony
rsyslog
dnf-plugins-core
httpd
```

This demonstrates an important multi-distribution concept:

```text
Same function
    !=
Same package name
```

---

# 2. Verify Desired State

Run:

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

---

# 3. Demonstrate Configuration Drift

Manually remove `jq` from one server.

Example:

```powershell
vagrant ssh ubu-prod01
```

Then:

```bash
sudo apt remove -y jq
```

Return to the control node:

```powershell
vagrant ssh sre-control01
```

Then:

```bash
source ~/venvs/ansible/bin/activate
cd /vagrant

ansible-playbook playbooks/baseline.yml
```

Ansible should reinstall `jq`.

This demonstrates:

```text
Desired State Enforcement
```

---

# 4. Audit Pending Updates

Run:

```bash
./scripts/run-audit.sh
```

or:

```bash
ansible-playbook playbooks/audit.yml
```

Reports are stored under:

```text
reports/
```

The audit checks pending package updates on both Ubuntu and Rocky.

---

# 5. Patch the Canary Ring

Always patch canary servers first.

Run:

```bash
./scripts/patch-canary.sh
```

Equivalent:

```bash
ansible-playbook playbooks/patch.yml --limit canary
```

Only these servers should be patched:

```text
ubu-canary01
rocky-canary01
```

The workflow includes:

```text
Pre-health check
      |
      v
Package update
      |
      v
Check reboot requirement
      |
      v
Reboot if required
      |
      v
SSH validation
      |
      v
Web-service validation
      |
      v
HTTP health check
```

---

# 6. Verify Canary

Run:

```bash
ansible canary -a "uptime"
```

Then:

```bash
ansible canary -a "curl -s http://127.0.0.1/health"
```

Do not promote the update to production unless the canary servers are healthy.

---

# 7. Patch Production

After canary validation:

```bash
./scripts/patch-production.sh
```

Equivalent:

```bash
ansible-playbook playbooks/patch.yml --limit production
```

The playbook uses:

```yaml
serial: 1
```

Therefore production hosts are patched one at a time.

This simulates rolling maintenance.

---

# 8. Package Version Policy

Run:

```bash
ansible-playbook playbooks/version-policy.yml
```

The lab demonstrates:

Ubuntu:

```text
apt-mark hold
```

Rocky:

```text
dnf versionlock
```

This introduces the difference between:

```text
package installed
package latest
package approved version
package held
package prohibited
```

---

# 9. Internal Repository

For the home lab, the repository service is hosted on:

```text
sre-control01
192.168.56.10
```

The Vagrant provisioning already installs:

```text
Nginx
Aptly
createrepo-c
GnuPG
```

and creates directories for later repository exercises.

---

## Ubuntu Repository Design

Recommended workflow:

```text
Ubuntu Upstream
      |
      v
Mirror
      |
      v
Snapshot
      |
      v
Test
      |
      v
Approved Snapshot
      |
      v
Published Internal APT Repo
```

Aptly is used to practice repository snapshots and promotion.

The important concept is:

```text
Production should not follow "latest".
```

Instead:

```text
Production
    |
    v
Approved immutable snapshot
```

---

## Rocky Repository Design

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

Target structure:

```text
/var/www/html/rpm/
└── rocky9/
    ├── dev/
    ├── canary/
    └── approved/
```

---

## Repository Client Configuration

Client repository configuration is demonstrated in:

```text
playbooks/repo-config.yml
```

Because this version combines repo and control roles, make sure any repository URLs point to:

```text
192.168.56.10
```

rather than the older separate-repository design that used `192.168.56.20`.

---

# Recommended Enterprise Patch Workflow

```text
Upstream Packages
       |
       v
Repository Sync
       |
       v
Snapshot / Version Policy
       |
       v
Package Audit
       |
       v
CANARY
       |
       v
Pre-health Check
       |
       v
Patch
       |
       v
Reboot if Required
       |
       v
Post-health Check
       |
       v
Approve
       |
       v
PRODUCTION
       |
       v
Audit / Report
```

The goal is not merely to run:

```bash
apt upgrade
```

or:

```bash
dnf update
```

The goal is to manage the complete package lifecycle safely and consistently.

---

# Failure Tests

See:

```text
docs/failure-tests.md
```

Recommended intentional failures:

| Test | Failure | Expected Behavior |
|---|---|---|
| 1 | Remove `jq` | Baseline restores it |
| 2 | Stop nginx/httpd | Pre-check prevents patch |
| 3 | Power off one VM | Ansible reports unreachable |
| 4 | Stop repository service | Repo operations fail visibly |
| 5 | Hold/versionlock package | Policy prevents upgrade |
| 6 | Install kernel update | Reboot requirement detected |
| 7 | Break `/health` endpoint | Rollout stops |
| 8 | Bad repository snapshot | Revert to previous approved snapshot |

A production-grade patch system must be able to **stop safely**, not just succeed when everything is healthy.

---

# Repository Structure

```text
linux-patch-lab/
├── Vagrantfile
├── README.md
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
│   ├── baseline/
│   ├── patch/
│   ├── healthcheck/
│   └── repo/
├── reports/
├── scripts/
│   ├── test-connectivity.sh
│   ├── run-audit.sh
│   ├── patch-canary.sh
│   └── patch-production.sh
├── docs/
│   ├── lab-topology.md
│   └── failure-tests.md
├── requirements.txt
└── .gitignore
```

---

# Git Ignore

Do not commit actual VirtualBox VM files or Vagrant runtime state.

Recommended `.gitignore` entries:

```gitignore
.vagrant/
*.vdi
*.vbox
*.vbox-prev

*.retry
*.log
.venv/
venv/
__pycache__/
reports/*.log
```

The Git repository should store:

```text
how to build the lab
```

not:

```text
the actual VMs
```

---

# Push to GitHub

If the repository has not been initialized yet:

```bash
git init
git add .
git commit -m "Initial Linux fleet package management lab"
git branch -M main
git remote add origin https://github.com/YOUR-USERNAME/linux-patch-lab.git
git push -u origin main
```

If the existing project is already connected to GitHub and you are only adding Vagrant support:

```bash
git add Vagrantfile README.md .gitignore
git commit -m "Add Vagrant-based lab provisioning"
git push
```

---

# Rebuilding the Entire Lab

Because the environment is defined in code, you can destroy it:

```powershell
vagrant destroy -f
```

Then rebuild it:

```powershell
vagrant up sre-control01
vagrant up
```

Then enter the control node:

```powershell
vagrant ssh sre-control01
```

And run:

```bash
source ~/venvs/ansible/bin/activate
cd /vagrant

ansible all -m ping
ansible-playbook playbooks/baseline.yml
```

This demonstrates a core Infrastructure-as-Code principle:

```text
VMs are disposable.

Configuration and automation are the source of truth.
```

---

# Future Enhancements

Recommended progression:

1. Refactor playbooks into reusable Ansible roles
2. Add Aptly repository snapshots
3. Add Rocky repository mirroring
4. Add automated repository promotion
5. Add AWX
6. Add Pulp
7. Integrate Zabbix health checks
8. Add CVE/security patch reporting
9. Add GitHub Actions validation
10. Generate HTML/JSON fleet patch reports
11. Add maintenance-window controls
12. Add automatic rollback workflow
13. Add an AI-SRE layer for proactive analysis and remediation recommendations

Possible future architecture:

```text
GitHub
   |
   v
CI Validation
   |
   v
AWX / Ansible
   |
   +------> Canary Fleet
   |
   +------> Production Fleet
   |
   v
Pulp / Aptly
   |
   v
Approved Package Snapshots

Zabbix
   |
   v
Health Verification

AI SRE
   |
   +-- analyze patch failures
   +-- find fleet drift
   +-- detect overdue security updates
   +-- recommend remediation
   +-- generate maintenance reports
```

---

# Key SRE Concepts Practiced

By completing this lab you should be able to explain:

```text
Infrastructure as Code
Configuration Management
Desired State
Configuration Drift
Multi-distribution Linux management
Package lifecycle management
Canary deployment
Rolling maintenance
Health gates
Reboot management
Repository snapshots
Version pinning
Failure containment
Automation auditing
```

A useful interview summary is:

> I built a reproducible multi-distribution Linux fleet lab using Vagrant and VirtualBox. Vagrant provisions the infrastructure, while Ansible manages Ubuntu and Rocky Linux hosts using canary and production patch rings, pre/post health validation, reboot detection, package policies, and internal repository concepts.
