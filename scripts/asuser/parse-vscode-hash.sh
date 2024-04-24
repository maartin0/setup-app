#!/bin/bash
CONFIG_LOCATION="$HOME/.config/code-server/config.yaml"
PROPERTY_NAME="hashed-password"
DATA=$(grep "$PROPERTY_NAME" "$CONFIG_LOCATION")
if ! [ $? = 0 ]; then
    exit 1
fi
printf "%s" "$DATA" | sed "s/$PROPERTY_NAME: //"