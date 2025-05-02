#!/bin/sh

# Prompt for username
printf "Enter new username: "
read USERNAME

# Prompt for password (securely)
printf "Enter password for %s: " "$USERNAME"
stty -echo
read PASSWORD
stty echo
printf "\n"

# Detect distro
if [ -f /etc/debian_version ]; then
    DISTRO=debian
elif [ -f /etc/alpine-release ]; then
    DISTRO=alpine
else
    echo "Unsupported distribution"
    exit 1
fi

# Function: check and install package
ensure_package() {
    PKG="$1"
    if [ "$DISTRO" = "debian" ]; then
        dpkg -s "$PKG" >/dev/null 2>&1 || apt install -y "$PKG"
    elif [ "$DISTRO" = "alpine" ]; then
        apk info -e "$PKG" >/dev/null 2>&1 || apk add "$PKG"
    fi
}

# Create user if not exists
if id "$USERNAME" >/dev/null 2>&1; then
    echo "User $USERNAME already exists."
else
    if [ "$DISTRO" = "debian" ]; then
        apt update -y
        ensure_package sudo
        useradd -m -s /bin/bash "$USERNAME"
    elif [ "$DISTRO" = "alpine" ]; then
        apk update
        ensure_package sudo
        ensure_package shadow
        adduser -D -s /bin/ash "$USERNAME"
    fi
    echo "$USERNAME:$PASSWORD" | chpasswd
    echo "User $USERNAME created."
fi

# Add to sudo/wheel group
if [ "$DISTRO" = "debian" ]; then
    if groups "$USERNAME" | grep -qw sudo; then
        echo "User $USERNAME already in sudo group."
    else
        usermod -aG sudo "$USERNAME"
        echo "User $USERNAME added to sudo group."
    fi

    SUDO_FILE="/etc/sudoers.d/$USERNAME"
    if [ -f "$SUDO_FILE" ]; then
        echo "Passwordless sudo already configured for $USERNAME."
    else
        echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" > "$SUDO_FILE"
        chmod 0440 "$SUDO_FILE"
        echo "Passwordless sudo configured for $USERNAME."
    fi

elif [ "$DISTRO" = "alpine" ]; then
    if grep -q "^$USERNAME:" /etc/group | grep -q wheel; then
        echo "User $USERNAME already in wheel group."
    else
        adduser "$USERNAME" wheel
        echo "User $USERNAME added to wheel group."
    fi

    if grep -q "^%wheel ALL=(ALL) NOPASSWD: ALL" /etc/sudoers; then
        echo "Passwordless sudo already configured for wheel group."
    else
        echo "%wheel ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
        echo "Passwordless sudo configured for wheel group."
    fi
fi

echo "✅ Done. $USERNAME is ready for Ansible usage."
