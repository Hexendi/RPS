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

# --- fake clip.exe / explorer.exe ---------------------------------------
cat >"$MOCKBIN/clip.exe" <<'MOCK'
#!/usr/bin/env bash
cat >"$RPS_TEST_CLIP"
MOCK
cat >"$MOCKBIN/explorer.exe" <<'MOCK'
#!/usr/bin/env bash
printf '%s\n' "$1" >"$RPS_TEST_EXPLORER"
MOCK
chmod +x "$MOCKBIN/clip.exe" "$MOCKBIN/explorer.exe"

ORIG_PATH=$PATH
export PATH="$REPO:$MOCKBIN:$PATH"
export RPS_TEST_CLIP="$SANDBOX/clip.out"
export RPS_TEST_EXPLORER="$SANDBOX/explorer.out"

# Does the host itself provide any of these tools? (for skip decisions)
HAVE_CLIP=0
HAVE_EXPLORER=0
for t in clip.exe xclip xsel wl-copy; do
    PATH="$ORIG_PATH" command -v "$t" >/dev/null 2>&1 && HAVE_CLIP=1
done
for t in explorer.exe wslview; do
    PATH="$ORIG_PATH" command -v "$t" >/dev/null 2>&1 && HAVE_EXPLORER=1
done

# bin dir with wslpath but *no* clipboard/explorer tools, for negative tests
NOEXT="$SANDBOX/bin_noext"
mkdir -p "$NOEXT"
cp "$MOCKBIN/wslpath" "$NOEXT/wslpath"

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

# --- -d: cd target -----------------------------------------------------
section "-d (cd target)"
eq "-d on a file gives its parent folder" \
    "$RPS_TEST_ROOT/mnt/c/Users/test" \
    "$(rps -d 'C:\Users\test\file.txt')"
eq "-d on a directory gives itself" \
    "$RPS_TEST_ROOT/mnt/c/Users/test/projects" \
    "$(rps -d 'C:\Users\test\projects')"
eq "-d on a missing path gives the path as-is" \
    "$RPS_TEST_ROOT/mnt/c/Users/test/nope" \
    "$(rps -d 'C:\Users\test\nope')"
eq "-d with no path gives cwd" \
    "$RPS_TEST_ROOT/mnt/c/Users/test" \
    "$(cd "$RPS_TEST_ROOT/mnt/c/Users/test" && rps -d)"

# --- -r: remove --------------------------------------------------------
section "-r (remove)"
printf 'x\n' >"$RPS_TEST_ROOT/mnt/c/Users/test/todelete.txt"
rc=0
out=$(printf 'y\n' | rps -r 'C:\Users\test\todelete.txt' 2>/dev/null) || rc=$?
eq "-r with yes removes the file" 0 "$rc"
if [ ! -e "$RPS_TEST_ROOT/mnt/c/Users/test/todelete.txt" ]; then
    ok "-r actually deletes the file"
else
    bad "-r actually deletes the file" "file gone" "file still exists"
fi
case "$out" in
    "removed: "*) ok "-r confirms on stdout" ;;
    *) bad "-r confirms on stdout" "starts with 'removed:'" "$out" ;;
esac

printf 'keep\n' >"$RPS_TEST_ROOT/mnt/c/Users/test/keep.txt"
printf 'n\n' | rps -r 'C:\Users\test\keep.txt' >/dev/null 2>&1
if [ -e "$RPS_TEST_ROOT/mnt/c/Users/test/keep.txt" ]; then
    ok "-r with no keeps the file"
else
    bad "-r with no keeps the file" "file exists" "file was deleted"
fi

rc=0
err=$(rps -r 'C:\Users\test\missing.txt' 2>&1 >/dev/null) || rc=$?
eq "-r on a missing file exits 1" 1 "$rc"
case "$err" in
    *"no such file"*) ok "-r on a missing file explains" ;;
    *) bad "-r on a missing file explains" "mentions 'no such file'" "$err" ;;
esac

# --- -c: clipboard ------------------------------------------------------
section "-c (copy)"
: >"$RPS_TEST_CLIP"
out=$(rps -c 'C:\Users\test\file.txt')
eq "clip gets the converted wsl path" \
    "$RPS_TEST_ROOT/mnt/c/Users/test/file.txt" \
    "$(cat "$RPS_TEST_CLIP")"
case "$out" in
    "copied: "*) ok "-c confirms on stdout" ;;
    *) bad "-c confirms on stdout" "starts with 'copied:'" "$out" ;;
esac

: >"$RPS_TEST_CLIP"
rps -c "$RPS_TEST_ROOT/mnt/c/Users/test/file.txt" >/dev/null
eq "clip gets the windows path for wsl input" \
    'C:\Users\test\file.txt' \
    "$(cat "$RPS_TEST_CLIP")"

# --- -e: Windows Explorer ----------------------------------------------
section "-e (open in Explorer)"
rps -e 'C:\Users\test\projects' >/dev/null
eq "explorer gets windows path (windows input)" \
    'C:\Users\test\projects' \
    "$(cat "$RPS_TEST_EXPLORER")"
out=$(rps -e "$RPS_TEST_ROOT/mnt/c/Users/test")
eq "explorer gets windows path (wsl input)" \
    'C:\Users\test' \
    "$(cat "$RPS_TEST_EXPLORER")"
case "$out" in
    "opened: "*) ok "-e confirms on stdout" ;;
    *) bad "-e confirms on stdout" "starts with 'opened:'" "$out" ;;
esac

# --- missing-helper negative tests (host-dependent, may skip) ----------
if [ "$HAVE_CLIP" -eq 0 ]; then
    rc=0
    err=$(PATH="$REPO:$NOEXT:/usr/bin:/bin" rps -c 'C:\x' 2>&1 >/dev/null) || rc=$?
    eq "-c without a clipboard tool exits 1" 1 "$rc"
    case "$err" in
        *"clipboard tool"*) ok "-c reports missing clipboard tool" ;;
        *) bad "-c reports missing clipboard tool" "mentions clipboard tool" "$err" ;;
    esac
else
    printf '  skip -c negative test (host provides a clipboard tool)\n'
fi
if [ "$HAVE_EXPLORER" -eq 0 ]; then
    rc=0
    err=$(PATH="$REPO:$NOEXT:/usr/bin:/bin" rps -e 'C:\x' 2>&1 >/dev/null) || rc=$?
    eq "-e without explorer/wslview exits 1" 1 "$rc"
    case "$err" in
        *"Explorer"*) ok "-e reports missing opener" ;;
        *) bad "-e reports missing opener" "mentions Explorer" "$err" ;;
    esac
else
    printf '  skip -e negative test (host provides an opener)\n'
fi

# --- shell integration (rps.sh) -----------------------------------------
section "shell integration: bash"
out=$(bash -c 'source "$1"; rps -d "$2"; pwd' _ "$REPO/rps.sh" 'C:\Users\test\projects')
eq "bash: rps -d cds into a directory" \
    "$RPS_TEST_ROOT/mnt/c/Users/test/projects" "$out"
out=$(bash -c 'source "$1"; rps -d "$2"; pwd' _ "$REPO/rps.sh" 'C:\Users\test\file.txt')
eq "bash: rps -d on a file cds to its parent" \
    "$RPS_TEST_ROOT/mnt/c/Users/test" "$out"
out=$(bash -c 'cd /; source "$1"; rps -b -d "$2"; pwd' _ "$REPO/rps.sh" 'C:\Users\test\projects')
eq "bash: -d works even when not the first flag" \
    "$RPS_TEST_ROOT/mnt/c/Users/test/projects" "$out"
out=$(bash -c 'cd /; source "$1"; rps -d "$2" 2>/dev/null; echo "rc=$? pwd=$(pwd)"' \
    _ "$REPO/rps.sh" 'C:\Users\test\nope')
eq "bash: failed cd keeps the old directory" "rc=1 pwd=/" "$out"
out=$(bash -c 'source "$1"; rps "$2"' _ "$REPO/rps.sh" 'C:\Users\test\file.txt')
eq "bash: plain rps delegates to the executable" \
    "$RPS_TEST_ROOT/mnt/c/Users/test/file.txt" "$out"
rc=0
out=$(bash -c 'source "$1"; complete -p rps' _ "$REPO/rps.sh" 2>&1) || rc=$?
eq "bash: completion registered" 0 "$rc"
case "$out" in
    *"-F _rps_complete_bash"*) ok "bash: completion uses _rps_complete_bash" ;;
    *) bad "bash: completion uses _rps_complete_bash" "complete -p shows -F" "$out" ;;
esac

section "shell integration: zsh"
out=$(zsh -c 'source "$1"; rps -d "$2"; pwd' _ "$REPO/rps.sh" 'C:\Users\test\projects')
eq "zsh: rps -d cds into a directory" \
    "$RPS_TEST_ROOT/mnt/c/Users/test/projects" "$out"
out=$(zsh -c 'source "$1"; rps "$2"' _ "$REPO/rps.sh" 'C:\Users\test\file.txt')
eq "zsh: plain rps delegates to the executable" \
    "$RPS_TEST_ROOT/mnt/c/Users/test/file.txt" "$out"
rc=0
out=$(zsh -c 'autoload -Uz compinit && compinit -D -u &&
    source "$1" && print -r -- "${_comps[rps]:-unregistered}"' \
    _ "$REPO/rps.sh" 2>&1) || rc=$?
eq "zsh: sourcing with compinit succeeds" 0 "$rc"
eq "zsh: completion registered" "_rps_complete_zsh" "$out"

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
rc=0
rps -r -d 'C:\x' >/dev/null 2>&1 || rc=$?
eq "conflicting actions exit 2" 2 "$rc"

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
