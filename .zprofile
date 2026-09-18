# Homebrew
if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv zsh)"
elif [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv zsh)"
fi

# Docker Desktop CLI
if [[ -d "$HOME/.docker/bin" ]]; then
    export PATH="$PATH:$HOME/.docker/bin"
fi
