#!/usr/bin/env python3
import sys

def folderPath(path):
    for i in range(len(path) - 1, -1, -1):
        if path[i] == "/":
            return path[:i]
    return ""

def WslPath(path):
    path = path.replace("C:", "/mnt/c")
    path = path.replace("\\", "/")
    return path

if len(sys.argv) < 2:
    print("Error: Missing arguments")
    sys.exit(1)

option = sys.argv[1]

if option in ["-h", "--help"]:
    print("""
Usage:
    rps <windows_path>
    rps -d <windows_path>    
    rps -r <windows_path>    
Options:
    -d --directory           Navigate to the file directory
    -r --remove              Remove the file from Windows
    -h --help                Show this help message    
    """)
    sys.exit(0)

path = sys.argv[2] if len(sys.argv) > 2 else option
wsl_path = WslPath(path)

if option in ["-d","--directory"]:
    print(folderPath(wsl_path))
elif option in ["-r","--remove"]:
    print(wsl_path)
else:
    print(wsl_path)  
