#!/bin/bash

echo "Running initialization script..."

# branch from parameter
if [ -z "$1" ]; then
    echo "Error: Branch parameter is empty. Please provide a valid branch name."
    exit 1
fi
BRANCH="$1"

# Copy all contents from persistent /per to root directory (/) without overwriting
cp -r --no-preserve=ownership,mode /per/* /

# allow execution of /root/.bashrc and /root/.profile
chmod 444 /root/.bashrc
chmod 444 /root/.profile

# Run A0 as host user so that files written to the mounted /a0 volume are owned
# by the host user rather than root.  Pass PUID / PGID via the
# environment (e.g. from docker-compose.yml).
PUID=${PUID:-0}
PGID=${PGID:-0}

if [ "$PUID" -ne 0 ]; then
    echo "Setting up a0user (UID=$PUID, GID=$PGID)..."
    groupadd -f -g "$PGID" a0group 2>/dev/null || true
    useradd -u "$PUID" -g "$PGID" -m -s /bin/bash a0user 2>/dev/null || true
    usermod -aG sudo a0user 2>/dev/null || true
    echo "a0user ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/a0user || true
    echo "Fixing ownership of /a0..."
    chown -R "$PUID:$PGID" /a0
    echo "Patching supervisord to run A0 services as a0user..."
    sed -i '/^\[program:run_ui\]/,/^\[/ s/^user=root$/user=a0user/' /etc/supervisor/conf.d/supervisord.conf
    sed -i '/^\[program:run_ui\]/,/^\[/ s|^environment=$|environment=HOME="/home/a0user"|' /etc/supervisor/conf.d/supervisord.conf
    sed -i '/^\[program:run_tunnel_api\]/,/^\[/ s/^user=root$/user=a0user/' /etc/supervisor/conf.d/supervisord.conf
    sed -i '/^\[program:run_tunnel_api\]/,/^\[/ s|^environment=$|environment=HOME="/home/a0user"|' /etc/supervisor/conf.d/supervisord.conf
fi

# update package list to save time later
apt-get update > /dev/null 2>&1 &

# let supervisord handle the services
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
