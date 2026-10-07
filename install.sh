#!/usr/bin/env bash
#
# Installer for rps.
#
#   ./install.sh               install (checks, copies, hooks, verifies)
#   ./install.sh --uninstall   remove everything this script installed
#   ./install.sh --help        show usage
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

# ------------------------------------------------------------ output style
if [ -t 1 ]; then
    G=$'\033[32m'
    Y=$'\033[33m'
    R=$'\033[31m'
    DIM=$'\033[2m'
    BOLD=$'\033[1m'
    OFF=$'\033[0m'
else
    G=''
    Y=''
    R=''
    DIM=''
    BOLD=''
    OFF=''
fi

banner() {
    printf '%s\n' "${BOLD}========================================${OFF}"
    printf '%s\n' "${BOLD}  rps — Windows ⇄ WSL path tool${OFF}"
    printf '%s\n' "${BOLD}========================================${OFF}"
}
step() { printf '\n%s%s%s\n' "$BOLD" "$1" "$OFF"; }
ok() { printf '  %s✓%s %s\n' "$G" "$OFF" "$*"; }
warn() { printf '  %s!%s %s\n' "$Y" "$OFF" "$*"; }
fail() { printf '  %s✗%s %s\n' "$R" "$OFF" "$*"; }
info() { printf '  %s·%s %s\n' "$DIM" "$OFF" "$*"; }

progress() {
    local p="$1" i bar=""
    for ((i = 0; i < 30; i++)); do
        if [ "$i" -lt $((p * 30 / 100)) ]; then
            bar+="█"
        else
            bar+="░"
        fi
    done
    printf '\r  %s%s%s %3d%%' "$G" "$bar" "$OFF" "$p"
}
animate() { [ -t 1 ] || return 0; progress "$1"; sleep 0.05; }
end_progress() { [ -t 1 ] || return 0; printf '\n'; }

# ------------------------------------------------------------------ input
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

block=$(cat <<'EOF'
# >>> RPS TOOL >>>
case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) export PATH="$HOME/.local/bin:$PATH" ;; esac
if [ -f "$HOME/.config/rps/rps.sh" ]; then
    . "$HOME/.config/rps/rps.sh"
fi
# <<< RPS TOOL <<<
EOF
)

# --------------------------------------------------------------- uninstall
if [ "$uninstall" -eq 1 ]; then
    banner
    step "1/2  Removing shell hooks"
    for f in "${rc_files[@]}"; do
        if [ -f "$f" ]; then
            strip_block "$f"
            ok "$f"
        fi
    done
    step "2/2  Removing installed files"
    rm -f "$BIN_DIR/rps" "$CONF_DIR/rps.sh"
    rmdir "$CONF_DIR" 2>/dev/null || true
    ok "$BIN_DIR/rps"
    ok "$CONF_DIR/rps.sh"
    printf '\n%sDone.%s Open a new terminal to finish.\n' "$BOLD" "$OFF"
    exit 0
fi

# ---------------------------------------------------------------- install
banner

step "1/4  Checking requirements"
ok "bash $BASH_VERSION"
ok "login shell: ${SHELL##*/}"
if command -v wslpath >/dev/null 2>&1; then
    ok "wslpath found — path conversion ready"
else
    warn "wslpath not found — this is not WSL ($(uname -sr))"
    info "rps installs fine here, but conversion only works inside WSL"
fi
clip_tool=""
for t in clip.exe xclip xsel wl-copy; do
    if command -v "$t" >/dev/null 2>&1; then
        clip_tool=$t
    fi
done
if [ -n "$clip_tool" ]; then
    ok "clipboard tool: $clip_tool (for -c)"
else
    warn "no clipboard tool — install xclip/xsel/wl-copy to use -c"
fi
opener=""
for t in explorer.exe wslview; do
    if command -v "$t" >/dev/null 2>&1; then
        opener=$t
    fi
done
if [ -n "$opener" ]; then
    ok "opener: $opener (for -e)"
else
    warn "no explorer.exe/wslview — -e only works inside WSL"
fi
case ":$PATH:" in
    *":$BIN_DIR:"*) ok "$BIN_DIR already in PATH" ;;
    *) info "$BIN_DIR not in PATH yet — the shell hook adds it" ;;
esac

step "2/4  Installing files"
mkdir -p "$BIN_DIR" "$CONF_DIR"
animate 25
cp "$REPO/rps" "$BIN_DIR/rps"
chmod +x "$BIN_DIR/rps"
animate 60
cp "$REPO/rps.sh" "$CONF_DIR/rps.sh"
animate 100
end_progress
ok "$BIN_DIR/rps"
ok "$CONF_DIR/rps.sh"

step "3/4  Setting up your shell"
for f in "${rc_files[@]}"; do
    touch "$f"
    strip_block "$f"
    # make sure the hook starts on its own line
    if [ -s "$f" ] && [ -n "$(tail -c 1 "$f")" ]; then
        printf '\n' >>"$f"
    fi
    printf '%s\n' "$block" >>"$f"
    ok "hook -> $f"
done

step "4/4  Verifying installation"
verify_fail=0
if "$BIN_DIR/rps" --help >/dev/null 2>&1; then
    ok "rps --help runs"
else
    fail "rps --help does not run"
    verify_fail=1
fi
if bash -n "$CONF_DIR/rps.sh"; then
    ok "rps.sh parses in bash"
else
    fail "rps.sh has bash syntax errors"
    verify_fail=1
fi
if command -v zsh >/dev/null 2>&1; then
    if zsh -n "$CONF_DIR/rps.sh"; then
        ok "rps.sh parses in zsh"
    else
        fail "rps.sh has zsh syntax errors"
        verify_fail=1
    fi
fi
if out=$(bash -c 'source "$1"; type -t rps' _ "$CONF_DIR/rps.sh" 2>/dev/null) &&
    [ "$out" = "function" ]; then
    ok "rps function loads (cd support ready)"
else
    fail "rps function did not load"
    verify_fail=1
fi
if command -v wslpath >/dev/null 2>&1; then
    if out=$("$BIN_DIR/rps" -u 'C:\rps\smoke-test' 2>/dev/null); then
        ok "conversion smoke test: C:\\rps\\smoke-test -> $out"
    else
        warn "conversion smoke test failed (rps is still installed)"
    fi
fi
if [ "$verify_fail" -ne 0 ]; then
    printf '\n%sInstallation FAILED verification.%s\n' "$R" "$OFF"
    exit 1
fi

printf '\n%sInstalled successfully!%s\n' "$BOLD" "$OFF"
printf '  rps --help      list every command\n'
if command -v wslpath >/dev/null 2>&1; then
    printf '  rps "C:\\Users\\%s\\Downloads"   try a conversion\n' "$(whoami)"
else
    printf '  %snote:%s conversion needs WSL — this machine has no wslpath\n' "$Y" "$OFF"
fi
printf '  ./install.sh --uninstall   remove everything\n'
printf '\nOpen a new terminal, or run:  source %s\n' "${rc_files[0]}"
