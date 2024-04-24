#!/bin/bash
USERNAME="$1"
if ! id "$USERNAME"; then
    echo "Couldn't find user with provided username"
    exit 1
fi

NEW_PASSWORD="$2"
if [ -z ${NEW_PASSWORD+x} ]; then
    echo "No password provided"
    exit 1
fi

if grep ":" <<< "$USERNAME"; then
    echo "Found illegal character (:) in username, exiting..."
    exit 1
fi

# Change linux password
echo "$USERNAME:$NEW_PASSWORD" | chpasswd

# Change vscode password
PASSWORD_HASH="$(./scripts/util/hash-with-argon2.sh "$NEW_PASSWORD")"
CONFIG_ROOT="/home/$USERNAME/.config/code-server/"
mkdir -p "$CONFIG_ROOT"
CONFIG_LOCATION="${CONFIG_ROOT}config.yaml"
PROPERTY_NAME="hashed-password"

# If config already has been initialised
if [ -f "$CONFIG_LOCATION" ]; then
    PAIR="${PROPERTY_NAME}: '${PASSWORD_HASH}'"
    # Remove existing hashed-password entries
    sed -i '/^hashed-password:/d' "$CONFIG_LOCATION"
    # Append pair to file
    printf '%s' "$PAIR" >> "$CONFIG_LOCATION"
    # Remove any (non-hashed) "password:" entries from the file
    sed -i '/^password:/d' "$CONFIG_LOCATION"

    # Restart instance if it was already running
    SERVICE_NAME="code-server@$USERNAME"
    if systemctl --quiet --no-pager status "$SERVICE_NAME"; then
        systemctl restart "$SERVICE_NAME"
    fi
else
    # If config hasn't been initialised, initialise it with password hash
    echo "Initialising vscode with password hash"
    ./scripts/asroot/init-vscode.sh "$USERNAME" "$PASSWORD_HASH"
fi

exit 0