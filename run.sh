#!/bin/bash
\. .env
BIND_ADDRESS="0.0.0.0:${BIND_PORT+8999}"
gunicorn -w 4 'app:app' -b "$BIND_ADDRESS"