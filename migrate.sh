#!/usr/bin/env bash

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRY_RUN=false
SKIP_BREW=false
BACKUP_DIR="$HOME/.unix-config-backup-$(date +%Y%m%d-%H%M%S)"

usage() {
    cat <<'EOF'
Usage: ./migrate.sh [options]

Restore Homebrew applications and tracked shell configuration.

Options:
  --dry-run    Print actions without changing the system.
  --skip-brew  Skip Xcode Command Line Tools and Homebrew restoration.
  -h, --help   Show this help.
EOF
}

log() {
    printf '\n==> %s\n' "$*"
}

warn() {
    printf 'Warning: %s\n' "$*" >&2
}

die() {
    printf 'Error: %s\n' "$*" >&2
    exit 1
}

run() {
    if [[ "$DRY_RUN" == true ]]; then
        printf '  [dry-run]'
        printf ' %q' "$@"
        printf '\n'
        return
    fi

    printf '  ->'
    printf ' %q' "$@"
    printf '\n'
    "$@"
}

find_brew() {
    if command -v brew >/dev/null 2>&1; then
        command -v brew
        return
    fi

    local candidate
    for candidate in /opt/homebrew/bin/brew /usr/local/bin/brew; do
        if [[ -x "$candidate" ]]; then
            printf '%s\n' "$candidate"
            return
        fi
    done

    return 1
}

link_item() {
    local source_path="$1"
    local destination="$2"
    local label="$3"

    [[ -e "$source_path" ]] || die "Missing tracked file: $source_path"

    if [[ -L "$destination" ]] && [[ "$(readlink "$destination")" == "$source_path" ]]; then
        printf '  = %s already linked\n' "$label"
        return
    fi

    if [[ -e "$destination" ]] || [[ -L "$destination" ]]; then
        if [[ "$DRY_RUN" == true ]]; then
            printf '  [dry-run] back up %s to %s\n' "$destination" "$BACKUP_DIR"
        else
            mkdir -p "$BACKUP_DIR"
            mv "$destination" "$BACKUP_DIR/$(basename "$destination")"
            printf '  -> backed up %s\n' "$destination"
        fi
    fi

    run mkdir -p "$(dirname "$destination")"
    run ln -s "$source_path" "$destination"
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)
            DRY_RUN=true
            ;;
        --skip-brew)
            SKIP_BREW=true
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            usage >&2
            die "Unknown option: $1"
            ;;
    esac
    shift
done

[[ "$(uname -s)" == "Darwin" ]] || die "This migration script only supports macOS."

for required_file in .zshrc .zprofile starship.toml Brewfile; do
    [[ -f "$REPO_DIR/$required_file" ]] || die "Missing repository file: $required_file"
done

if [[ "$SKIP_BREW" == false ]]; then
    log "Checking Xcode Command Line Tools"
    if ! xcode-select -p >/dev/null 2>&1; then
        warn "Xcode Command Line Tools are not installed."
        if [[ "$DRY_RUN" == true ]]; then
            printf '  [dry-run] xcode-select --install\n'
        else
            xcode-select --install || true
            die "Finish the Xcode Command Line Tools installation, then run this script again."
        fi
    else
        printf '  = Xcode Command Line Tools already installed\n'
    fi

    log "Checking Homebrew"
    brew_bin="$(find_brew || true)"
    if [[ -z "$brew_bin" ]]; then
        warn "Homebrew is not installed."
        if [[ "$DRY_RUN" == true ]]; then
            printf '  [dry-run] install Homebrew from https://brew.sh\n'
        else
            /bin/bash -c "$(/usr/bin/curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
            brew_bin="$(find_brew || true)"
            [[ -n "$brew_bin" ]] || die "Homebrew installation finished, but brew was not found."
        fi
    else
        printf '  = Found %s\n' "$brew_bin"
    fi

    if [[ -n "$brew_bin" ]]; then
        if [[ "$DRY_RUN" == false ]]; then
            eval "$("$brew_bin" shellenv)"
        fi
        log "Restoring Homebrew applications"
        run "$brew_bin" bundle install --file "$REPO_DIR/Brewfile"
    fi
fi

log "Linking tracked shell configuration"
link_item "$REPO_DIR/.zshrc" "$HOME/.zshrc" "\$HOME/.zshrc"
link_item "$REPO_DIR/.zprofile" "$HOME/.zprofile" "\$HOME/.zprofile"
link_item "$REPO_DIR/starship.toml" "$HOME/.config/starship.toml" "\$HOME/.config/starship.toml"

log "Validating configuration"
run zsh -n "$REPO_DIR/.zshrc"

if command -v starship >/dev/null 2>&1; then
    run env STARSHIP_CONFIG="$REPO_DIR/starship.toml" starship print-config
elif [[ "$DRY_RUN" == false ]]; then
    warn "starship is not available; skipped Starship validation."
fi

missing_commands=""
for command_name in starship zoxide fnm fzf nvim svn gh go; do
    if ! command -v "$command_name" >/dev/null 2>&1; then
        missing_commands="$missing_commands $command_name"
    fi
done

printf '\nMigration complete.\n'
printf 'Open a new terminal, or run: exec zsh -l\n'

if [[ -n "$missing_commands" ]]; then
    warn "Commands not found after migration:$missing_commands"
fi

if [[ -d "$BACKUP_DIR" ]]; then
    printf 'Previous files were backed up to: %s\n' "$BACKUP_DIR"
fi

cat <<'EOF'

Manual items are not installed by this script:
  - Bun (~/.bun)
  - Docker Desktop (~/.docker)
  - Navicat Premium and its local helper script
  - Visual Studio Code extensions
EOF
