#!/bin/bash
SSH_DIR="$HOME/.ssh"
PRIVATE_KEY="$SSH_DIR/id_tmp"
PUBLIC_KEY="$PRIVATE_KEY.pub"
AUTHORIZED_KEYS="$SSH_DIR/authorized_keys"

clear () {
    rm -f "$PRIVATE_KEY" "$PUBLIC_KEY"
}
clear

ssh-keygen -q -t ed25519 -N '' -f "$PRIVATE_KEY"
cat "$PUBLIC_KEY" >> "$AUTHORIZED_KEYS"
cat "$PRIVATE_KEY"

clear