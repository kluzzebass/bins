#!/bin/sh

echo "🚀 Starting user setup script..."

# Prompt for username
printf "👤 Enter new username: "
read USERNAME

# Detect distro
if [ -f /etc/debian_version ]; then
    DISTRO=debian
    echo "📦 Detected Debian-based distribution"
elif [ -f /etc/alpine-release ]; then
    DISTRO=alpine
    echo "📦 Detected Alpine Linux"
else
    echo "❌ Unsupported distribution"
    exit 1
fi

# Function: check and install package
ensure_package() {
    PKG="$1"
    if [ "$DISTRO" = "debian" ]; then
        if dpkg -s "$PKG" >/dev/null 2>&1; then
            echo "✅ Package '$PKG' already installed"
        else
            echo "📥 Installing package '$PKG'..."
            apt install -y "$PKG"
        fi
    elif [ "$DISTRO" = "alpine" ]; then
        if apk info -e "$PKG" >/dev/null 2>&1; then
            echo "✅ Package '$PKG' already installed"
        else
            echo "📥 Installing package '$PKG'..."
            apk add "$PKG"
        fi
    fi
}

# If user doesn't exist, ask for password and create
if id "$USERNAME" >/dev/null 2>&1; then
    echo "✅ User '$USERNAME' already exists, skipping creation and password prompt"
else
    # Prompt for password (securely)
    printf "🔒 Enter password for %s: " "$USERNAME"
    stty -echo
    read PASSWORD
    stty echo
    printf "\n"

    echo "👷 Creating user '$USERNAME'..."
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
    echo "🔐 Password set for user '$USERNAME'"
fi

# Add to sudo/wheel group
if [ "$DISTRO" = "debian" ]; then
    if id -nG "$USERNAME" | grep -qw sudo; then
        echo "✅ User '$USERNAME' already in 'sudo' group"
    else
        echo "➕ Adding user '$USERNAME' to 'sudo' group..."
        usermod -aG sudo "$USERNAME"
    fi

    SUDO_FILE="/etc/sudoers.d/$USERNAME"
    if [ -f "$SUDO_FILE" ]; then
        echo "✅ Passwordless sudo already configured for '$USERNAME'"
    else
        echo "📝 Setting up passwordless sudo for '$USERNAME'..."
        echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" > "$SUDO_FILE"
        chmod 0440 "$SUDO_FILE"
    fi

elif [ "$DISTRO" = "alpine" ]; then
    if id -nG "$USERNAME" | grep -qw wheel; then
        echo "✅ User '$USERNAME' already in 'wheel' group"
    else
        echo "➕ Adding user '$USERNAME' to 'wheel' group..."
        adduser "$USERNAME" wheel
    fi

    if grep -q "^%wheel ALL=(ALL) NOPASSWD: ALL" /etc/sudoers; then
        echo "✅ Passwordless sudo already configured for 'wheel' group"
    else
        echo "📝 Adding passwordless sudo rule for 'wheel' group..."
        echo "%wheel ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
    fi
fi

# Ensure SSH server is installed and started
if [ "$DISTRO" = "debian" ]; then
    ensure_package openssh-server
    if command -v systemctl >/dev/null 2>&1; then
        echo "🔌 Enabling and starting SSH service (systemd)..."
        systemctl enable ssh
        systemctl restart ssh
    else
        echo "⚠️ systemd not available — ensure SSH is running manually"
    fi
elif [ "$DISTRO" = "alpine" ]; then
    ensure_package openssh
    echo "🔌 Enabling and starting sshd (OpenRC)..."
    rc-update add sshd
    service sshd restart
fi

echo "🎉 Done. User '$USERNAME' is ready with passwordless sudo and SSH access."
