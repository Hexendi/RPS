# rps shell integration — source this file from ~/.bashrc or ~/.zshrc
# (install.sh does that for you).
#
# It defines the `rps` function so `rps -d` can actually cd (a plain
# script cannot change its parent shell's directory), and registers tab
# completion. Everything else is delegated to the `rps` executable on
# PATH.

rps() {
    local _a _want_cd=0
    for _a in "$@"; do
        case "$_a" in
            -d | --directory) _want_cd=1 ;;
            --) break ;;
        esac
    done

    if [ "$_want_cd" -eq 1 ]; then
        local _target
        _target=$(command rps "$@") || return $?
        if [ -n "$_target" ]; then
            cd -- "$_target"
        fi
    else
        command rps "$@"
    fi
}

# --- tab completion ------------------------------------------------------
if [ -n "${BASH_VERSION:-}" ]; then
    _rps_complete_bash() {
        local cur="${COMP_WORDS[COMP_CWORD]}"
        if [[ "$cur" == -* ]]; then
            COMPREPLY=($(compgen -W \
                '-h --help -u --wsl -w --win -b --both -d --directory -r --remove -c --copy -e --explorer --' \
                -- "$cur"))
        else
            COMPREPLY=($(compgen -f -- "$cur"))
        fi
    }
    complete -F _rps_complete_bash rps 2>/dev/null || true
elif [ -n "${ZSH_VERSION:-}" ]; then
    _rps_complete_zsh() {
        _arguments \
            '(-h --help)'{-h,--help}'[show this help]' \
            '(-u --wsl)'{-u,--wsl}'[force WSL format]' \
            '(-w --win)'{-w,--win}'[force Windows format]' \
            '(-b --both)'{-b,--both}'[print both formats]' \
            '(-d --directory)'{-d,--directory}'[cd into the directory]' \
            '(-r --remove)'{-r,--remove}'[remove the file]' \
            '(-c --copy)'{-c,--copy}'[copy converted path to clipboard]' \
            '(-e --explorer)'{-e,--explorer}'[open in Windows Explorer]' \
            '*:path:_files'
    }
    compdef _rps_complete_zsh rps 2>/dev/null || true
fi
