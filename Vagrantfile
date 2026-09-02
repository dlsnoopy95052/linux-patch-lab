# -*- mode: ruby -*-
# vi: set ft=ruby :
#
# Linux Fleet Package & Patch Management Lab
# VirtualBox + Vagrant
#
# Topology:
#   sre-control01      192.168.56.10  Ubuntu 24.04  Ansible + Git + repo tools
#   ubu-canary01       192.168.56.31  Ubuntu 24.04  Canary
#   ubu-prod01         192.168.56.32  Ubuntu 24.04  Production
#   rocky-canary01     192.168.56.41  Rocky 9       Canary
#   rocky-prod01       192.168.56.42  Rocky 9       Production
#
# Recommended first run:
#   vagrant up sre-control01
#   vagrant up
#
# Once everything is up:
#   vagrant ssh sre-control01
#   source ~/venvs/ansible/bin/activate
#   cd /vagrant
#   ansible all -m ping

LAB_NODES = {
  "sre-control01" => {
    box: "bento/ubuntu-24.04",
    ip: "192.168.56.10",
    memory: 4096,
    cpus: 2,
    role: :control
  },
  "ubu-canary01" => {
    box: "bento/ubuntu-24.04",
    ip: "192.168.56.31",
    memory: 2048,
    cpus: 2,
    role: :managed
  },
  "ubu-prod01" => {
    box: "bento/ubuntu-24.04",
    ip: "192.168.56.32",
    memory: 2048,
    cpus: 2,
    role: :managed
  },
  "rocky-canary01" => {
    box: "bento/rockylinux-9",
    ip: "192.168.56.41",
    memory: 2048,
    cpus: 2,
    role: :managed
  },
  "rocky-prod01" => {
    box: "bento/rockylinux-9",
    ip: "192.168.56.42",
    memory: 2048,
    cpus: 2,
    role: :managed
  }
}.freeze

HOSTS_BLOCK = <<~HOSTS
  # SRE-LAB-BEGIN
  192.168.56.10 sre-control01
  192.168.56.31 ubu-canary01
  192.168.56.32 ubu-prod01
  192.168.56.41 rocky-canary01
  192.168.56.42 rocky-prod01
  # SRE-LAB-END
HOSTS

Vagrant.configure("2") do |config|
  config.vm.boot_timeout = 600
  config.vm.box_check_update = true

  # The default /vagrant shared folder is useful on the control node because
  # it exposes this Git project to Ansible. Managed nodes disable it below so
  # Rocky kernel patching cannot be disrupted by a VirtualBox shared-folder
  # / Guest Additions mismatch after reboot.

  LAB_NODES.each do |name, node|
    config.vm.define name, primary: (name == "sre-control01") do |vm|
      vm.vm.box = node[:box]
      vm.vm.hostname = name

      # Vagrant creates a VirtualBox host-only/private adapter for this network.
      # NAT remains available as the first adapter for Internet access.
      vm.vm.network "private_network", ip: node[:ip]

      vm.vm.provider "virtualbox" do |vb|
        vb.name = "sre-lab-#{name}"
        vb.memory = node[:memory]
        vb.cpus = node[:cpus]
        vb.gui = false
      end

      # Put all lab names into /etc/hosts on every machine.
      vm.vm.provision "shell", privileged: true, inline: <<-SHELL
        set -euo pipefail

        sed -i '/# SRE-LAB-BEGIN/,/# SRE-LAB-END/d' /etc/hosts
        cat >> /etc/hosts <<'EOF_HOSTS'
#{HOSTS_BLOCK.rstrip}
EOF_HOSTS
      SHELL

      if node[:role] == :control
        # Keep the Git project mounted on the control node.
        vm.vm.synced_folder ".", "/vagrant"

        vm.vm.provision "shell", privileged: true, inline: <<-'SHELL'
          set -euo pipefail

          echo "[control] Installing Ansible, Git, repo tools, and utilities..."
          export DEBIAN_FRONTEND=noninteractive
          apt-get update
          apt-get install -y \
            python3 \
            python3-pip \
            python3-venv \
            git \
            jq \
            curl \
            nginx \
            gnupg \
            aptly \
            createrepo-c

          # Ansible virtual environment for the vagrant user.
          install -d -m 0755 -o vagrant -g vagrant /home/vagrant/venvs
          if [ ! -x /home/vagrant/venvs/ansible/bin/ansible ]; then
            sudo -u vagrant python3 -m venv /home/vagrant/venvs/ansible
            sudo -u vagrant /home/vagrant/venvs/ansible/bin/pip install --upgrade pip
            sudo -u vagrant /home/vagrant/venvs/ansible/bin/pip install ansible
          fi

          # Generate the SSH key Ansible will use to manage the fleet.
          install -d -m 0700 -o vagrant -g vagrant /home/vagrant/.ssh
          if [ ! -f /home/vagrant/.ssh/id_ed25519 ]; then
            sudo -u vagrant ssh-keygen \
              -t ed25519 \
              -N '' \
              -C 'sre-control01 lab ansible key' \
              -f /home/vagrant/.ssh/id_ed25519
          fi

          # Publish only the public key over the lab network. Managed nodes
          # fetch this file during provisioning, so they do not need /vagrant.
          cp /home/vagrant/.ssh/id_ed25519.pub /var/www/html/sre-control01.pub
          chmod 0644 /var/www/html/sre-control01.pub

          # Keep a copy in the Git worktree for visibility; it is public-key
          # material only and is safe to recreate.
          install -d -m 0755 /vagrant/generated
          cp /home/vagrant/.ssh/id_ed25519.pub /vagrant/generated/sre-control01.pub
          chmod 0644 /vagrant/generated/sre-control01.pub

          # Prepare directories for the later internal APT/RPM repository labs.
          install -d -m 0755 /var/www/html/apt
          install -d -m 0755 /var/www/html/rpm/rocky9/approved
          systemctl enable --now nginx

          cat > /home/vagrant/LAB-START-HERE.txt <<'EOF'
          Linux Patch Lab control node is ready.

          Run:
            source ~/venvs/ansible/bin/activate
            cd /vagrant
            ansible-inventory --graph
            ansible all -m ping
            ansible-playbook playbooks/baseline.yml
          EOF
          chown vagrant:vagrant /home/vagrant/LAB-START-HERE.txt

          echo "[control] Provisioning complete."
        SHELL
      else
        # Managed nodes do not need the host project folder. This also avoids
        # VirtualBox Guest Additions/shared-folder coupling after kernel patches.
        vm.vm.synced_folder ".", "/vagrant", disabled: true

        vm.vm.provision "shell", privileged: true, inline: <<-'SHELL'
          set -euo pipefail

          echo "[managed] Preparing node for Ansible management..."

          # Ensure Python exists for Ansible modules.
          if command -v apt-get >/dev/null 2>&1; then
            export DEBIAN_FRONTEND=noninteractive
            apt-get update
            apt-get install -y python3 curl sudo
          elif command -v dnf >/dev/null 2>&1; then
            dnf install -y python3 curl sudo
          else
            echo "Unsupported package manager" >&2
            exit 1
          fi

          # Create an enterprise-style management account for the lab.
          if ! id sysadmin >/dev/null 2>&1; then
            useradd -m -s /bin/bash sysadmin
          fi

          if getent group sudo >/dev/null 2>&1; then
            usermod -aG sudo sysadmin
          elif getent group wheel >/dev/null 2>&1; then
            usermod -aG wheel sysadmin
          fi

          cat > /etc/sudoers.d/90-sysadmin <<'EOF_SUDO'
          sysadmin ALL=(ALL) NOPASSWD: ALL
          EOF_SUDO
          chmod 0440 /etc/sudoers.d/90-sysadmin

          # Wait for sre-control01 to publish its public key over Nginx. This
          # is why the safest first run is: vagrant up sre-control01 && vagrant up
          rm -f /tmp/sre-control01.pub
          for _ in $(seq 1 60); do
            if curl -fsS http://192.168.56.10/sre-control01.pub               -o /tmp/sre-control01.pub && [ -s /tmp/sre-control01.pub ]; then
              break
            fi
            sleep 2
          done

          if [ ! -s /tmp/sre-control01.pub ]; then
            echo "ERROR: could not retrieve the control-node public key." >&2
            echo "Run: vagrant up sre-control01, then reprovision this VM." >&2
            exit 1
          fi

          install -d -m 0700 -o sysadmin -g sysadmin /home/sysadmin/.ssh
          cat /tmp/sre-control01.pub > /home/sysadmin/.ssh/authorized_keys
          chown sysadmin:sysadmin /home/sysadmin/.ssh/authorized_keys
          chmod 0600 /home/sysadmin/.ssh/authorized_keys

          echo "[managed] Provisioning complete."
        SHELL
      end
    end
  end
end
