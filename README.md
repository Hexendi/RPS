# rps — Windows path adapter for WSL

Convert a Windows path to a WSL path instantly.

## Install

```bash
git clone https://github.com/Hexendi/REPEASEL-rps-.git
cd rps
chmod +x install.sh
./install.sh
```

Close and reopen your WSL terminal.

## Usage

```bash
# Convert a path
rps "C:\Users\moussa\file.txt"
→ /mnt/c/Users/moussa/file.txt

# cd into the folder
rps -d "C:\Users\moussa\file.txt"

# Delete the file
rps -r "C:\Users\moussa\file.txt"
```

## Requirements

- WSL
- Python 3
