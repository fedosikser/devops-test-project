#!/usr/bin/env bash
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run this script as root: sudo bash scripts/provision-vm.sh" >&2
  exit 1
fi

DEPLOYER_USER="${DEPLOYER_USER:-deployer}"
PUBLIC_KEY_FILE="${PUBLIC_KEY_FILE:-/tmp/deployer.pub}"

if [[ ! -s "${PUBLIC_KEY_FILE}" ]]; then
  echo "Public key file not found or empty: ${PUBLIC_KEY_FILE}" >&2
  exit 1
fi

if ! id "${DEPLOYER_USER}" >/dev/null 2>&1; then
  adduser --disabled-password --gecos "" "${DEPLOYER_USER}"
fi
usermod -aG sudo "${DEPLOYER_USER}"
printf '%s ALL=(ALL) NOPASSWD:ALL\n' "${DEPLOYER_USER}" > "/etc/sudoers.d/${DEPLOYER_USER}"
chmod 0440 "/etc/sudoers.d/${DEPLOYER_USER}"

install -d -m 700 -o "${DEPLOYER_USER}" -g "${DEPLOYER_USER}" "/home/${DEPLOYER_USER}/.ssh"
install -m 600 -o "${DEPLOYER_USER}" -g "${DEPLOYER_USER}" "${PUBLIC_KEY_FILE}" "/home/${DEPLOYER_USER}/.ssh/authorized_keys"

apt-get update
apt-get install -y ca-certificates curl ufw

if ! command -v docker >/dev/null 2>&1 || ! docker compose version >/dev/null 2>&1; then
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  chmod a+r /etc/apt/keyrings/docker.asc
  . /etc/os-release
  printf 'deb [arch=%s signed-by=%s] https://download.docker.com/linux/ubuntu %s stable\n' \
    "$(dpkg --print-architecture)" "/etc/apt/keyrings/docker.asc" \
    "${UBUNTU_CODENAME:-$VERSION_CODENAME}" > /etc/apt/sources.list.d/docker.list
  apt-get update
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
fi

systemctl enable --now docker
usermod -aG docker "${DEPLOYER_USER}"

install -d -m 0755 /etc/ssh/sshd_config.d
cat > /etc/ssh/sshd_config.d/99-deployer-hardening.conf <<'EOF'
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitRootLogin no
PubkeyAuthentication yes
EOF
sshd -t
systemctl reload ssh

ufw default deny incoming
ufw default allow outgoing
ufw allow OpenSSH
ufw allow 80/tcp
ufw --force enable

echo "VM provisioning completed for ${DEPLOYER_USER}."
