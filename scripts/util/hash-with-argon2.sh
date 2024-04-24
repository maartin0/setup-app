#!/bin/bash
\. ./scripts/util/make-npm-avaliable.sh 2&>/dev/null
npm exec --package=argon2-cli -c "printf '%s' $1 | argon2-cli -e"