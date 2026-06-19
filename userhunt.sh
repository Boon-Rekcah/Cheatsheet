#!/usr/bin/env bash
#
# user-check.sh
# ----------------------------------------------------------------------
# Runs standard NetExec checks against a host list for a given
# credential, so you don't have to type each command manually.
#
# Usage:
#   ./user-check.sh
#   (prompts for username, credential, and MSSQL port interactively)
# ----------------------------------------------------------------------

# ---- Edit this path to point at your IP list -------------------------
IP_LIST="/root/Desktop/enterprise-network/internal/host_discovery/ip.txt"
# ----------------------------------------------------------------------

# ---- Separator printed between each check ----------------------------
SEP="=================================================================="

# ---- Where per-run output is captured for the final summary ----------
LOGFILE="$(mktemp /tmp/user-check.XXXXXX.log)"

# Strip ANSI colour codes so the summary greps cleanly
strip_ansi() { sed -r 's/\x1b\[[0-9;]*m//g'; }

# Print a few blank lines + a banner before each check so scans are
# visually separated and easy to read while scrolling back.
banner() {
    echo ""
    echo ""
    echo "$SEP"
    echo "[*] $1"
    echo "$SEP"
}

# NetExec disables its colours when stdout is a pipe (and we pipe into
# `tee` to capture output for the summary). `unbuffer` (from the expect
# package) gives NetExec a pseudo-terminal so it keeps colour output,
# while we still capture everything for the end-of-run summary.
PTY=""
if command -v unbuffer >/dev/null 2>&1; then
    PTY="unbuffer"
fi

# Run a netexec command, show it live (in colour if possible), AND tee
# it to the logfile.
run_check() {
    # "$@" is the full netexec command
    if [ -n "$PTY" ]; then
        $PTY "$@" 2>&1 | tee -a "$LOGFILE"
    else
        "$@" 2>&1 | tee -a "$LOGFILE"
    fi
}

# ---- Prompt for credentials ------------------------------------------
read -rp "Username: " USERNAME

echo ""
echo "Authenticate with:"
echo "  1) Password"
echo "  2) Hash"
read -rp "Choice [1/2]: " AUTH_CHOICE
echo ""

AUTH_FLAG=""
AUTH_VALUE=""

if [ "$AUTH_CHOICE" == "1" ]; then
    read -rsp "Password: " AUTH_VALUE
    echo ""
    AUTH_FLAG="-p"
elif [ "$AUTH_CHOICE" == "2" ]; then
    read -rsp "Hash (format LM:NT or just NT): " AUTH_VALUE
    echo ""
    AUTH_FLAG="-H"
else
    echo "[-] Invalid choice. Enter 1 for Password or 2 for Hash."
    exit 1
fi

# ---- Prompt for MSSQL port -------------------------------------------
echo ""
read -rp "MSSQL port [default 1433]: " MSSQL_PORT
# Fall back to the default instance port if nothing is entered
if [ -z "$MSSQL_PORT" ]; then
    MSSQL_PORT="1433"
fi

# ---- Sanity checks ---------------------------------------------------
if [ -z "$USERNAME" ] || [ -z "$AUTH_VALUE" ]; then
    echo "[-] Username and credential cannot be empty."
    exit 1
fi

if ! [[ "$MSSQL_PORT" =~ ^[0-9]+$ ]]; then
    echo "[-] MSSQL port must be a number."
    exit 1
fi

if [ ! -f "$IP_LIST" ]; then
    echo "[-] IP list not found at: $IP_LIST"
    echo "    Edit the IP_LIST variable at the top of this script."
    exit 1
fi

if ! command -v netexec >/dev/null 2>&1; then
    echo "[-] netexec not found in PATH."
    exit 1
fi

echo ""
echo "[*] Running checks for user: $USERNAME"
echo "[*] Auth method: $([ "$AUTH_FLAG" == "-p" ] && echo "Password" || echo "Hash")"
echo "[*] MSSQL port:  $MSSQL_PORT"
echo "[*] Against hosts in: $IP_LIST"
if [ -z "$PTY" ]; then
    echo "[!] 'unbuffer' not found -- NetExec colours will be disabled."
    echo "    Install it for coloured output:  sudo apt install expect"
fi

# ====================================================================
# DOMAIN AUTH CHECKS
# ====================================================================

banner "CHECK 1/10 -- SMB (Domain Auth)"
run_check netexec smb "$IP_LIST" -u "$USERNAME" "$AUTH_FLAG" "$AUTH_VALUE" --continue-on-success

banner "CHECK 2/10 -- WINRM (Domain Auth)"
run_check netexec winrm "$IP_LIST" -u "$USERNAME" "$AUTH_FLAG" "$AUTH_VALUE" --continue-on-success

banner "CHECK 3/10 -- RDP (Domain Auth)"
run_check netexec rdp "$IP_LIST" -u "$USERNAME" "$AUTH_FLAG" "$AUTH_VALUE" --continue-on-success

banner "CHECK 4/10 -- MSSQL (Domain Auth, port $MSSQL_PORT)"
run_check netexec mssql "$IP_LIST" -u "$USERNAME" "$AUTH_FLAG" "$AUTH_VALUE" --port "$MSSQL_PORT" --continue-on-success

banner "CHECK 5/10 -- SMB SHARES (Domain Auth)"
run_check netexec smb "$IP_LIST" -u "$USERNAME" "$AUTH_FLAG" "$AUTH_VALUE" --shares --continue-on-success

# ====================================================================
# LOCAL AUTH CHECKS
# ====================================================================

banner "CHECK 6/10 -- SMB (Local Auth)"
run_check netexec smb "$IP_LIST" -u "$USERNAME" "$AUTH_FLAG" "$AUTH_VALUE" --local-auth --continue-on-success

banner "CHECK 7/10 -- WINRM (Local Auth)"
run_check netexec winrm "$IP_LIST" -u "$USERNAME" "$AUTH_FLAG" "$AUTH_VALUE" --local-auth --continue-on-success

banner "CHECK 8/10 -- RDP (Local Auth)"
run_check netexec rdp "$IP_LIST" -u "$USERNAME" "$AUTH_FLAG" "$AUTH_VALUE" --local-auth --continue-on-success

banner "CHECK 9/10 -- MSSQL (Local Auth, port $MSSQL_PORT)"
run_check netexec mssql "$IP_LIST" -u "$USERNAME" "$AUTH_FLAG" "$AUTH_VALUE" --port "$MSSQL_PORT" --local-auth --continue-on-success

banner "CHECK 10/10 -- SMB SHARES (Local Auth)"
run_check netexec smb "$IP_LIST" -u "$USERNAME" "$AUTH_FLAG" "$AUTH_VALUE" --local-auth --shares --continue-on-success

# ====================================================================
# SUMMARY -- pull the interesting lines out of the captured output
# ====================================================================

echo ""
echo ""
echo ""
echo "$SEP"
echo "[+] ALL CHECKS COMPLETE FOR USER: $USERNAME"
echo "$SEP"

# Successful authentications: NetExec marks these with [+]
SUCCESS="$(strip_ansi < "$LOGFILE" | grep -aF '[+]' | sort -u)"

# Admin / full compromise: NetExec appends (Pwn3d!) on those lines
PWNED="$(strip_ansi < "$LOGFILE" | grep -aF 'Pwn3d!' | sort -u)"

# Readable/writable shares from the --shares checks
SHARES="$(strip_ansi < "$LOGFILE" | grep -aiE 'READ|WRITE' | sort -u)"

echo ""
echo ">>> SUCCESSFUL LOGINS <<<"
if [ -n "$SUCCESS" ]; then
    echo "$SUCCESS"
else
    echo "    (none)"
fi

echo ""
echo ">>> ADMIN / Pwn3d! ACCESS <<<"
if [ -n "$PWNED" ]; then
    echo "$PWNED"
else
    echo "    (none)"
fi

echo ""
echo ">>> ACCESSIBLE SHARES (READ/WRITE) <<<"
if [ -n "$SHARES" ]; then
    echo "$SHARES"
else
    echo "    (none found / no share checks succeeded)"
fi

echo ""
echo "$SEP"
echo "[*] Full raw output saved to: $LOGFILE"
echo "$SEP"
