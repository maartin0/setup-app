#!/bin/bash
# Install nvm
if ! command -v npm; then
    if ! command -v nvm; then
        # If nvm hasn't been installed
        if ! [ -d "$HOME/.nvm" ]; then
            curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
        fi
        # If nvm has been installed but isn't avaliable 
        export NVM_DIR="$HOME/.nvm"
        [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
        [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
    fi
    # Install npm
    nvm install --lts
fi