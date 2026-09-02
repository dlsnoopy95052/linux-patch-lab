# -*- mode: ruby -*-
# vi: set ft=ruby :

# Linux Fleet Package & Patch Management Lab
# VirtualBox + Vagrant
#
# Recommended first build:
#   vagrant up sre-control01
#   vagrant up ubu-canary01 ubu-prod01 rocky-canary01 rocky-prod01
#
# Then:
#   vagrant ssh sre-control01
#   source ~/venvs/ansible/bin/activate
#   cd /vagrant
#   ansible-inventory --graph
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

Vagrant.configure("2") do |config|
  config.vm.boot_timeout = 600
  config.vm.box_check_update = true

  LAB_NODES.each do |name, node|
    config.vm.define name, primary: (name == "sre-control01") do |vm|
      vm.vm.box = node[:box]
      vm.vm.hostname = name
      vm.vm.network "private_network", ip: node[:ip]

      vm.vm.provider "virtualbox" do |vb|
        vb.name = "sre-lab-#{name}"
        vb.memory = node[:memory]
        vb.cpus = node[:cpus]
        vb.gui = false
      end

      # Keep hostnames consistent on all lab nodes.
      vm.vm.provision "shell", privileged: true, inline: <<-SHELL
        set -e
        sed -i '/# SRE-LAB-BEGIN/,/# SRE-LAB-END/d' /etc/hosts
        printf '%s\n' \
          '# SRE-LAB-BEGIN' \
          '192.168.56.10 sre-control01' \
          '192.168.56.31 ubu-canary01' \
          '192.168.56.32 ubu-prod01' \
          '192.168.56.41 rocky-canary01' \
          '192.168.56.42 rocky-prod01' \
          '# SRE-LAB-END' >> /etc/hosts
      SHELL

      if node[:role] == :control
        # Only the control node needs the Git repo shared as /vagrant.
        vm.vm.synced_folder ".", "/vagrant"

        vm.vm.provision "shell", privileged: true, inline: <<-'SHELL'
          set -euo pipefail

          echo "[control] Installing Ansible, Git, Nginx, and repository tools..."
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

          # Ansible virtual environment.
          install -d -m 0755 -o vagrant -g vagrant /home/vagrant/venvs

          if [ ! -x /home/vagrant/venvs/ansible/bin/ansible ]; then
            sudo -u vagrant python3 -m venv /home/vagrant/venvs/ansible
            sudo -u vagrant /home/vagrant/venvs/ansible/bin/pip install --upgrade pip
            sudo -u vagrant /home/vagrant/venvs/ansible/bin/pip install ansible
          fi

          # Management SSH key used by Ansible.
          install -d -m 0700 -o vagrant -g vagrant /home/vagrant/.ssh

          if [ ! -f /home/vagrant/.ssh/id_ed25519 ]; then
            sudo -u vagrant ssh-keygen \
              -t ed25519 \
              -N '' \
              -C 'sre-control01 lab ansible key' \
              -f /home/vagrant/.ssh/id_ed25519
          fi

          # Publish ONLY the public key for managed-node provisioning.
          cp /home/vagrant/.ssh/id_ed25519.pub /var/www/html/sre-control01.pub
          chmod 0644 /var/www/html/sre-control01.pub

          install -d -m 0755 /vagrant/generated
          cp /home/vagrant/.ssh/id_ed25519.pub /vagrant/generated/sre-control01.pub
          chmod 0644 /vagrant/generated/sre-control01.pub

          # Repository lab directories.
          install -d -m 0755 /var/www/html/apt
          install -d -m 0755 /var/www/html/rpm/rocky9/approved
          systemctl enable --now nginx

          # /vagrant is a VirtualBox shared folder and is world-writable.
          # Ansible will otherwise ignore /vagrant/ansible.cfg.
          # Explicit ANSIBLE_CONFIG makes the project config usable.
          if ! grep -q 'ANSIBLE_CONFIG=/vagrant/ansible.cfg' /home/vagrant/.bashrc; then
            printf '%s\n' 'export ANSIBLE_CONFIG=/vagrant/ansible.cfg' >> /home/vagrant/.bashrc
          fi

          # Also create a normal home-directory Ansible config fallback.
          ln -sfn /vagrant/ansible.cfg /home/vagrant/.ansible.cfg
          chown -h vagrant:vagrant /home/vagrant/.ansible.cfg

          printf '%s\n' \
            'Linux Patch Lab control node is ready.' \
            '' \
            'Run:' \
            '  source ~/venvs/ansible/bin/activate' \
            '  export ANSIBLE_CONFIG=/vagrant/ansible.cfg' \
            '  cd /vagrant' \
            '  ansible-inventory --graph' \
            '  ansible all -m ping' \
            '  ansible-playbook playbooks/baseline.yml' \
            > /home/vagrant/LAB-START-HERE.txt

          chown vagrant:vagrant /home/vagrant/LAB-START-HERE.txt

          echo "[control] Provisioning complete."
        SHELL
      else
        # Managed nodes do not need /vagrant.
        vm.vm.synced_folder ".", "/vagrant", disabled: true

        vm.vm.provision "shell", privileged: true, inline: <<-'SHELL'
          set -euo pipefail

          echo "[managed] Preparing node for Ansible management..."

          # Python is needed by Ansible modules.
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

          # Create sysadmin management account.
          if ! id sysadmin >/dev/null 2>&1; then
            useradd -m -s /bin/bash sysadmin
          fi

          if getent group sudo >/dev/null 2>&1; then
            usermod -aG sudo sysadmin
          elif getent group wheel >/dev/null 2>&1; then
            usermod -aG wheel sysadmin
          fi

          # IMPORTANT: use printf instead of a nested heredoc.
          # This avoids accidentally writing the rest of the provisioning
          # script into the sudoers file.
          printf '%s\n' 'sysadmin ALL=(ALL) NOPASSWD: ALL' \
            > /etc/sudoers.d/90-sysadmin
          chmod 0440 /etc/sudoers.d/90-sysadmin
          visudo -cf /etc/sudoers.d/90-sysadmin

          # Retrieve the control-node public key.
          rm -f /tmp/sre-control01.pub

          for attempt in $(seq 1 60); do
            if curl -fsS \
              http://192.168.56.10/sre-control01.pub \
              -o /tmp/sre-control01.pub &&
              [ -s /tmp/sre-control01.pub ]; then
              break
            fi

            echo "[managed] Waiting for control-node SSH public key (${attempt}/60)..."
            sleep 2
          done

          if [ ! -s /tmp/sre-control01.pub ]; then
            echo "ERROR: could not retrieve the control-node public key." >&2
            echo "Build sre-control01 first, then reprovision this VM." >&2
            exit 1
          fi

          install -d -m 0700 -o sysadmin -g sysadmin /home/sysadmin/.ssh
          install -m 0600 -o sysadmin -g sysadmin \
            /tmp/sre-control01.pub \
            /home/sysadmin/.ssh/authorized_keys

          echo "[managed] Provisioning complete."
        SHELL
      end
    end
  end
end
