# rps — Windows ⇄ WSL path swiss army knife

Convert a path between Windows and WSL formats with one command — plus
`cd`, safe delete, clipboard copy, and "open in Explorer".

It's built on `wslpath`, so every drive (`C:`, `D:`, …), mixed
`\`/`/` separators and UNC paths just work.

## Install

```bash
git clone https://github.com/Hexendi/RPS.git
cd RPS
chmod +x install.sh
./install.sh
```

Restart your terminal (or `source ~/.bashrc` / `~/.zshrc`). Works in
**bash and zsh**.

The installer sets up:

- `~/.local/bin/rps` — the executable
- `~/.config/rps/rps.sh` — shell integration (cd support + tab completion)
- an idempotent source hook in `~/.bashrc` / `~/.zshrc` (re-running never
  duplicates it) that also keeps `~/.local/bin` on `PATH`

Uninstall everything with:

```bash
./install.sh --uninstall
```

## Usage

```bash
# Convert — direction is detected for you
rps "C:\Users\moussa\file.txt"        # → /mnt/c/Users/moussa/file.txt
rps "/mnt/c/Users/moussa/file.txt"    # → C:\Users\moussa\file.txt

# No arguments: both formats of the current directory
rps
/mnt/c/Users/moussa/projects/RPS
C:\Users\moussa\projects\RPS

# cd — a directory is used as-is, a file resolves to its folder
rps -d "C:\Users\moussa\projects\RPS" # cd /mnt/c/Users/moussa/projects/RPS
rps -d "C:\Users\moussa\file.txt"     # cd /mnt/c/Users/moussa

# Delete — asks for confirmation, never recursive
rps -r "C:\Users\moussa\Downloads\old.zip"

# Copy the converted path to the clipboard (no trailing newline)
rps -c "/mnt/c/Users/moussa\key.txt"  # clipboard gets C:\Users\moussa\key.txt

# Open the path in Windows Explorer
rps -e .
```

### Flags

| flag | what it does |
|------|--------------|
| `-u, --wsl` | force WSL format |
| `-w, --win` | force Windows format |
| `-b, --both` | print both formats (WSL first, Windows second) |
| `-d, --directory` | print the folder to cd into (the sourced wrapper does the actual `cd`) |
| `-r, --remove` | confirm and delete the file |
| `-c, --copy` | copy the converted path to the clipboard |
| `-e, --explorer` | open the path in Windows Explorer |
| `-h, --help` | show help |

Exit codes: `0` success, `1` runtime error (missing file, no `wslpath`, …),
`2` usage error.

## Why not just `wslpath`?

| | `wslpath` | `rps` |
|---|:---:|:---:|
| picks the direction for you | ✗ | ✓ |
| `cd` to a Windows path | ✗ | ✓ |
| both formats at a glance | ✗ | ✓ |
| copy to clipboard | ✗ | ✓ |
| open in Explorer | ✗ | ✓ |
| tab completion (bash + zsh) | ✗ | ✓ |
| confirm-before-delete | ✗ | ✓ |

## Requirements

- WSL (provides `wslpath`)
- bash or zsh
- Optional: `xclip`, `xsel` or `wl-copy` if `clip.exe` isn't reachable;
  `wslview` if `explorer.exe` isn't (both are normally there on WSL)

## Development

```bash
./tests/test_rps.sh
```

The test suite mocks `wslpath`, `clip.exe` and `explorer.exe`, so it runs
on any Linux — no WSL needed.
