#!/bin/bash
## This script used to add a bunch of patches to code-server and build it, 
# now it just clones it - which is why there's so many sad commented-out bits of code

if [ -d "code-server" ]; then
    echo "Found code-server directory"
    exit 1
fi

START_TIME=$(date +%s)



## Install dependencies
## nfpm isn't on the main apt repo
# echo 'deb [trusted=yes] https://repo.goreleaser.com/apt/ /' | sudo tee /etc/apt/sources.list.d/goreleaser.list
# apt-get update
# apt-get install -y nfpm
## All other deps
# apt-get install -y libkrb5-dev g++ gcc make python2.7 pkg-config libx11-dev libxkbfile-dev libsecret-1-dev jq

## Clone and build VS code if not cached
CODE_SERVER_DIR="code-server"
CODE_SERVER_VERSION="4.23.1"
# NODE_VERSION="18.19.1"

# Clone base repo
git clone https://github.com/coder/code-server.git  --branch "v${CODE_SERVER_VERSION}" --single-branch

## Apply patches
# FILE_TO_PATCH="$CODE_SERVER_DIR/src/node/http.ts"
# PATCH_FILE="patches/code_server_src_node_http.patched.ts"
# cp "$PATCH_FILE" "$FILE_TO_PATCH"
# FILE_TO_PATCH="$CODE_SERVER_DIR/src/node/routes/index.ts"
# PATCH_FILE="patches/code_server_src_node_routes_index.patched.ts"
# cp "$PATCH_FILE" "$FILE_TO_PATCH"

# Install VS code (requirement to build)
cd "$CODE_SERVER_DIR"
git submodule update --init

## Install nvm
# if ! command -v nvm; then
#     curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
#     export NVM_DIR="$HOME/.nvm"
#     [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
#     [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
# fi

## Install required node version
# nvm install "$NODE_VERSION"
# nvm use "$NODE_VERSION"

## Install yarn
# if ! command -v yarn; then
#     npm install -g yarn
# fi

## Build
# VERSION_BAK="$VERSION" # If $VERSION is set to something else, save it to $VERSION_BAK temporarily
# export VERSION="${CODE_SERVER_VERSION}"

# yarn
# yarn build
# yarn build:vscode
# yarn release
# yarn release:standalone
# yarn package

# EXAMPLE_PACKAGE="code-server_${VERSION}_amd64.deb"

# unset -v VERSION
# VERSION=$VERSION_BAK
# unset -v VERSION_BAK


cd ..

END_TIME=$(date +%s)
RUNTIME=$((END_TIME-START_TIME))

echo "Done! Took $RUNTIME seconds"
# echo "Now go to code-server/release-packages/" and install one of the packages there
# echo "e.g."
# echo "cd code-server/release-packages/"
# echo "sudo apt install -y ./$EXAMPLE_PACKAGE"
