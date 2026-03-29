#!/bin/bash
set -e

echo "Installing rps......."
mkdir -p ~/.local/bin
cp "$(dirname "$0")/repeasel.py" ~/.local/bin/repeasel.py
chmod +x ~/.local/bin/repeasel.py

sed -i '/# >>> RPS TOOL >>>/,/# <<< RPS TOOL <<</d' ~/.bashrc

cat >> ~/.bashrc << 'ENDOFBLOCK'
# >>> RPS TOOL >>>
if [ -n "$BASH_VERSION" ]; then
rps() {
    local result
    result=$(python3 ~/.local/bin/repeasel.py "$@")
    if [[ "$1" == "-d" ]]; then
        cd "$result" || return
    elif [[ "$1" == "-r" ]]; then
        rm -i "$result"
    else
        echo "$result"
    fi
}
fi
# <<< RPS TOOL <
ENDOFBLOCK

echo "................60%"
echo "...................70%"
echo "......................100%"
echo "Installed successfully!"
echo "Run: source ~/.bashrc"
echo ""
echo "Usage:"
echo '  rps "C:\Users\name\file.txt"       # convert path'
echo '  rps -d "C:\Users\name\file.txt"    # cd into "name" folder'
echo '  rps -r "C:\Users\name\file.txt"    # remove file'
echo '  rps -h                             # --help '
