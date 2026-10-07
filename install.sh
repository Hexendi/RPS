#!/usr/bin/env bash
#
# Installer for rps.
#
#   ./install.sh               install
#   ./install.sh --uninstall   remove everything this script installed
#   ./install.sh --help        show usage
#
# Installs the rps executable to ~/.local/bin, the shell integration to
# ~/.config/rps/rps.sh, and appends a source hook (idempotent) to
# ~/.bashrc and/or ~/.zshrc.
set -euo pipefail

REPO="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$HOME/.local/bin"
CONF_DIR="$HOME/.config/rps"
MARK_BEGIN='# >>> RPS TOOL >>>'
MARK_END='# <<< RPS TOOL <<<'

usage() {
    cat <<'EOF'
Usage:
    ./install.sh [--uninstall]

Installs rps:
    ~/.local/bin/rps           the rps executable
    ~/.config/rps/rps.sh       shell integration (cd support + completion)
    ~/.bashrc / ~/.zshrc       gets an idempotent source hook

    --uninstall                removes all of the above
EOF
}

uninstall=0
case "${1:-}" in
    "") ;;
    --uninstall) uninstall=1 ;;
    -h | --help)
        usage
        exit 0
        ;;
    *)
        usage >&2
        echo "install.sh: unknown option: $1" >&2
        exit 2
        ;;
esac

# Which rc files to hook: the ones that exist, plus the one matching the
# login shell (created if needed).
rc_files=()
for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
    if [ -f "$rc" ]; then
        rc_files+=("$rc")
    fi
done
case "${SHELL:-}" in
    */bash)
        [ -f "$HOME/.bashrc" ] || rc_files+=("$HOME/.bashrc")
        ;;
    */zsh)
        [ -f "$HOME/.zshrc" ] || rc_files+=("$HOME/.zshrc")
        ;;
esac
if [ "${#rc_files[@]}" -eq 0 ]; then
    rc_files=("$HOME/.bashrc")
fi

strip_block() {
    local f="$1"
    [ -f "$f" ] || return 0
    sed -i "/^$MARK_BEGIN\$/,/^$MARK_END\$/d" "$f"
}

if [ "$uninstall" -eq 1 ]; then
    echo "Uninstalling rps..."
    for f in "${rc_files[@]}"; do
        if [ -f "$f" ]; then
            strip_block "$f"
            echo "  - removed shell hook from $f"
        fi
    done
    rm -f "$BIN_DIR/rps" "$CONF_DIR/rps.sh"
    rmdir "$CONF_DIR" 2>/dev/null || true
    echo "  - removed $BIN_DIR/rps"
    echo "Done."
    exit 0
fi

block=$(cat <<'EOF'
# >>> RPS TOOL >>>
case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) export PATH="$HOME/.local/bin:$PATH" ;; esac
if [ -f "$HOME/.config/rps/rps.sh" ]; then
    . "$HOME/.config/rps/rps.sh"
fi
# <<< RPS TOOL <<<
EOF
)

echo "Installing rps..."
mkdir -p "$BIN_DIR" "$CONF_DIR"
cp "$REPO/rps" "$BIN_DIR/rps"
chmod +x "$BIN_DIR/rps"
cp "$REPO/rps.sh" "$CONF_DIR/rps.sh"
echo "  + $BIN_DIR/rps"
echo "  + $CONF_DIR/rps.sh"

for f in "${rc_files[@]}"; do
    touch "$f"
    strip_block "$f"
    # make sure the hook starts on its own line
    if [ -s "$f" ] && [ -n "$(tail -c 1 "$f")" ]; then
        printf '\n' >>"$f"
    fi
    printf '%s\n' "$block" >>"$f"
    echo "  + shell hook -> $f"
done

echo "Done. Open a new terminal, or run:  source ${rc_files[0]}"
echo "Try:  rps \"C:\\Users\\$(whoami)\\Downloads\""
