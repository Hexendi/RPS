#!/usr/bin/env bash
# Test suite for rps.
#
# Runs anywhere (including plain Linux/CI): a fake `wslpath` on PATH maps
# C:\... <-> $RPS_TEST_ROOT/mnt/c/... so filesystem operations can be
# exercised without a real WSL install.
set -u

REPO="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
SANDBOX=$(mktemp -d)
trap 'rm -rf "$SANDBOX"' EXIT

export RPS_TEST_ROOT="$SANDBOX/root"
MOCKBIN="$SANDBOX/bin"
mkdir -p "$RPS_TEST_ROOT/mnt/c/Users/test/projects/RPS" "$MOCKBIN"
printf 'hello\n' >"$RPS_TEST_ROOT/mnt/c/Users/test/file.txt"

# --- fake wslpath -------------------------------------------------------
cat >"$MOCKBIN/wslpath" <<'MOCK'
#!/usr/bin/env bash
mode="${1:-}"
p="${2:-}"
root="$RPS_TEST_ROOT"
case "$mode" in
    -u)
        case "$p" in
            [A-Za-z]:[\\/]*)
                drive="${p:0:1}"
                rest="${p:2}"
                rest="${rest//\\//}"
                rest="${rest#/}"
                printf '%s/mnt/%s/%s\n' "$root" "${drive,,}" "$rest"
                ;;
            *)
                echo "wslpath: $p: invalid Windows path" >&2
                exit 1
                ;;
        esac
        ;;
    -w)
        case "$p" in
            "$root"/mnt/*)
                rel="${p#"$root/mnt/"}"
                drive="${rel%%/*}"
                if [ "$rel" = "$drive" ]; then
                    rest=""
                else
                    rest="${rel#*/}"
                fi
                rest="${rest//\//\\}"
                printf '%s:\\%s\n' "${drive^^}" "$rest"
                ;;
            [A-Za-z]:*)
                printf '%s\n' "$p"
                ;;
            *)
                echo "wslpath: $p: invalid WSL path" >&2
                exit 1
                ;;
        esac
        ;;
    *)
        echo "usage: wslpath (-u|-w|-m) PATH" >&2
        exit 1
        ;;
esac
MOCK
chmod +x "$MOCKBIN/wslpath"

ORIG_PATH=$PATH
export PATH="$REPO:$MOCKBIN:$PATH"

# --- tiny test framework ------------------------------------------------
PASS=0
FAIL=0

section() { printf '\n%s\n' "$1"; }
ok() { PASS=$((PASS + 1)); printf '  ok   %s\n' "$1"; }
bad() {
    FAIL=$((FAIL + 1))
    printf '  FAIL %s\n    expected: %s\n    actual:   %s\n' "$1" "${2:-}" "${3:-}"
}
eq() { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1" "$2" "$3"; fi; }

# --- help ---------------------------------------------------------------
section "help"
rc=0
out=$("$REPO/rps" -h) || rc=$?
eq "rps -h exits 0" 0 "$rc"
case "$out" in
    *Usage:*) ok "help shows usage" ;;
    *) bad "help shows usage" "contains 'Usage:'" "$out" ;;
esac
case "$out" in
    *"--both"*) ok "help lists flags" ;;
    *) bad "help lists flags" "contains '--both'" "$out" ;;
esac

# --- auto conversion ----------------------------------------------------
section "auto conversion"
eq "windows -> wsl" \
    "$RPS_TEST_ROOT/mnt/c/Users/test/file.txt" \
    "$(rps 'C:\Users\test\file.txt')"
eq "windows forward slashes -> wsl" \
    "$RPS_TEST_ROOT/mnt/c/Users/test/file.txt" \
    "$(rps 'C:/Users/test/file.txt')"
eq "wsl -> windows" \
    'C:\Users\test\file.txt' \
    "$(rps "$RPS_TEST_ROOT/mnt/c/Users/test/file.txt")"
eq "forced -u" \
    "$RPS_TEST_ROOT/mnt/c/Users/test" \
    "$(rps -u 'C:\Users\test')"
eq "forced -w" \
    'C:\Users\test\file.txt' \
    "$(rps -w "$RPS_TEST_ROOT/mnt/c/Users/test/file.txt")"

# --- both formats -------------------------------------------------------
section "both formats"
eq "no args: both formats of cwd" \
    "$RPS_TEST_ROOT/mnt/c/Users/test"$'\n'C:'\Users\test' \
    "$(cd "$RPS_TEST_ROOT/mnt/c/Users/test" && rps)"
eq "-b on windows path: wsl first, windows second" \
    "$RPS_TEST_ROOT/mnt/c/Users"$'\n'C:'\Users' \
    "$(rps -b 'C:\Users')"
eq "-b on wsl path: wsl first, windows second" \
    "$RPS_TEST_ROOT/mnt/c"$'\n'C:'\' \
    "$(rps -b "$RPS_TEST_ROOT/mnt/c")"

# --- error handling -----------------------------------------------------
section "error handling"
rc=0
rps --bogus >/dev/null 2>&1 || rc=$?
eq "unknown option exits 2" 2 "$rc"
rc=0
rps a b >/dev/null 2>&1 || rc=$?
eq "too many args exits 2" 2 "$rc"
rc=0
rps 'C:\nope' 'extra' >/dev/null 2>&1 || rc=$?
eq "path + extra flag exits 2" 2 "$rc"

# Missing wslpath (only runnable where no real wslpath exists)
REAL_WSLPATH=$(PATH="$ORIG_PATH" command -v wslpath 2>/dev/null || true)
if [ -z "$REAL_WSLPATH" ]; then
    rc=0
    err=$(PATH="$REPO:/usr/bin:/bin" rps 'C:\x' 2>&1 >/dev/null) || rc=$?
    eq "missing wslpath exits 1" 1 "$rc"
    case "$err" in
        *"wslpath not found"*) ok "missing wslpath reports clearly" ;;
        *) bad "missing wslpath reports clearly" "mentions wslpath" "$err" ;;
    esac
else
    printf '  skip missing-wslpath tests (real wslpath at %s)\n' "$REAL_WSLPATH"
fi

# --- summary ------------------------------------------------------------
printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
