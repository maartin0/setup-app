#!/bin/bash
USERNAME="$1"
DEFAULT_PASSWORD_HASH="$2"

if ! id "$USERNAME"; then
    echo "Couldn't find user with provided username"
    exit 1
fi

PORT_COUNTER="lastport.txt"
if ! [ -f "$PORT_COUNTER" ]; then
    echo "Couldn't find port counter. Is this being run by app.py (i.e. in the correct environment/working directory)?"
    exit 1
fi

update_owner () {
    chown "$USERNAME" "$1"
    chmod 600 "$1"
}

CONFIG_ROOT="/home/$USERNAME/.config/code-server/"
mkdir -p "$CONFIG_ROOT"
CONFIG_LOCATION="${CONFIG_ROOT}config.yaml"
CONFIG_TEMPLATE_LOCATION="./patches/code_server_config_template.yaml"
SHOULD_RESTART_CODE_SERVER=0

# Write code-server's config with template if it isn't initialised
if ! [ -f "$CONFIG_LOCATION" ]; then 
    echo "Initialising config file at $CONFIG_LOCATION as user $USERNAME"
    cat "$CONFIG_TEMPLATE_LOCATION" > "$CONFIG_LOCATION"
    SHOULD_RESTART_CODE_SERVER=1
fi

# If there's no port cached, increment port counter by one and update file in user dir 
PORT_CACHE_LOCATION="/home/$USERNAME/.setupappport"
if ! [ -f "$PORT_CACHE_LOCATION" ]; then
    # Calculate next port
    PORT=$(("$(cat "$PORT_COUNTER")"+1))
    # Update port counter
    echo "$PORT" > "$PORT_COUNTER"
    # Update cache
    echo "$PORT" > "$PORT_CACHE_LOCATION"
    echo "Couldn't find cached port, using $PORT"
else
    PORT="$(cat "$PORT_CACHE_LOCATION")"
    echo "Using cached port $PORT"
fi

# Update code-server's config if port is not up-to-date 
if ! grep -q "$PORT" "$CONFIG_LOCATION"; then
    echo "Setting port in config file"
    # Replace template's default port (8080) with $PORT
    sed -i "s/8080/$PORT/" "$CONFIG_LOCATION"
    SHOULD_RESTART_CODE_SERVER=1
fi

# Set default password if provided and not already set
PROPERTY_NAME="hashed-password"
if ! grep -q "$PROPERTY_NAME" "$CONFIG_LOCATION"; then
    if [ -z "$DEFAULT_PASSWORD_HASH" ]; then
        # Generate random password
        echo "Generating random password to store in config"
        NEW_PASSWORD_DATA="$(base64 /dev/urandom | head -c 32)"
        NEW_PASSWORD_HASH="$(./scripts/util/hash-with-argon2.sh "${NEW_PASSWORD_DATA}")"
    else
        # Use provided hash
        echo "Using provided password hash in vscode config"
        NEW_PASSWORD_HASH="$DEFAULT_PASSWORD_HASH"
    fi
    # Store password
    printf "\n%s: %s" "${PROPERTY_NAME}" "${NEW_PASSWORD_HASH}" >> "$CONFIG_LOCATION"
    SHOULD_RESTART_CODE_SERVER=1
fi
# Remove any (non-hashed) "password:" entries from the file
sed -i '/^password:/d' "$CONFIG_LOCATION"

# Setup nginx for $USERNAME
NGINX_MODULE_DIR="/etc/nginx/setup-app/"
NGINX_USER_FILE="${NGINX_MODULE_DIR}${USERNAME}.conf"
SHOULD_RESTART_NGINX=0
if ! grep "$PORT" "$NGINX_USER_FILE"; then
    NGINX_MODULE_TEMPLATE="patches/nginx_module_template.conf"
    mkdir -p "$NGINX_MODULE_DIR"
    cat "$NGINX_MODULE_TEMPLATE" > "$NGINX_USER_FILE"
    sed -i "s/PORT/$PORT/" "$NGINX_USER_FILE"
    sed -i "s/USER/$USERNAME/" "$NGINX_USER_FILE"
    SHOULD_RESTART_NGINX=1
fi

# Stop nginx to start again if config was updated
if [ $SHOULD_RESTART_NGINX = 1 ]; then
    echo "Restarting nginx"
    systemctl stop nginx
fi

# Start nginx if stopped above or not running yet
systemctl start nginx

# Stop service to start again if port/config was updated
SERVICE_NAME="code-server@$USERNAME"
if [ $SHOULD_RESTART_CODE_SERVER = 1 ]; then
    echo "Restarting $SERVICE_NAME service"
    systemctl stop "$SERVICE_NAME"
fi

# Set user-file owners
update_owner "$CONFIG_LOCATION"
update_owner "$PORT_CACHE_LOCATION"

# Start service if stopped above or not running yet
systemctl start "$SERVICE_NAME"

exit 0