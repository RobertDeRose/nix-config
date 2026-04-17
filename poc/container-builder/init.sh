#!/bin/sh
set -e
export PATH="/root/.nix-profile/bin:$PATH"

# Create builder user
if ! id builder > /dev/null 2>&1; then
  echo "builder:x:1000:1000:builder:/home/builder:/bin/sh" >> /etc/passwd
  echo "builder:x:1000:" >> /etc/group
  mkdir -p /home/builder
  chown 1000:1000 /home/builder
fi

# Configure nix
mkdir -p /etc/nix
cat > /etc/nix/nix.conf << 'EOF'
trusted-users = root builder
experimental-features = nix-command flakes
build-users-group =
EOF

# Set up SSH authorized keys
mkdir -p /home/builder/.ssh
cp /config/builder_ed25519.pub /home/builder/.ssh/authorized_keys
chmod 700 /home/builder/.ssh
chmod 600 /home/builder/.ssh/authorized_keys
chown -R 1000:1000 /home/builder/.ssh

# Give builder access to nix binaries
mkdir -p /home/builder/.nix-profile/bin
ln -sf /root/.nix-profile/bin/* /home/builder/.nix-profile/bin/ 2> /dev/null || true

# Set up host key
mkdir -p /etc/ssh
cp /config/ssh_host_ed25519_key /etc/ssh/
chmod 600 /etc/ssh/ssh_host_ed25519_key

# Create sshd privsep user
if ! id sshd > /dev/null 2>&1; then
  echo "sshd:x:74:74:sshd privsep:/var/empty:/bin/false" >> /etc/passwd
  echo "sshd:x:74:" >> /etc/group
  mkdir -p /var/empty
fi

# Configure sshd — listen on ALL interfaces so port publishing works
mkdir -p /run/sshd
cat > /etc/ssh/sshd_config << 'EOF'
ListenAddress 0.0.0.0:22
HostKey /etc/ssh/ssh_host_ed25519_key
PermitRootLogin no
PubkeyAuthentication yes
PasswordAuthentication no
ChallengeResponseAuthentication no
UsePAM no
PrintMotd no
AcceptEnv LANG LC_*
SetEnv PATH=/root/.nix-profile/bin:/nix/var/nix/profiles/default/bin:/usr/bin:/bin:/usr/sbin:/sbin
Subsystem sftp /root/.nix-profile/libexec/sftp-server
MaxStartups 64:30:128
MaxSessions 64
EOF

# Start nix-daemon in background
nix-daemon &

# Start sshd as main process (foreground)
exec $(which sshd) -D -e
