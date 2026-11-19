# Run a LOCAL shell script inside the modern webserver VM over SSH.
#
# Design notes, learned the hard way:
#
#   1. Quoting: passing multi-line shell as one ssh argument gets mangled by
#      PowerShell -> ssh -> bash. The script is base64-encoded instead, so only
#      [A-Za-z0-9+/=] ever crosses the wire.
#
#   2. Line endings: Git on Windows may check files out with CRLF, and bash
#      treats the trailing \r as part of the command ("$'\r': command not
#      found"). Encoding to base64 on the Windows side and decoding remotely
#      removes the problem entirely, because the decoder writes exactly the
#      bytes we encoded.
#
#   3. stdin: `bash -s` would consume the script from stdin, and any command
#      that reads stdin (sudo without -S) would eat the rest of the script.
#      Running from a file avoids that.
#
#   4. sudo: the lab user is not the Debian cloud default user, so cloud-init
#      did not create a NOPASSWD rule for it. The password is written to a
#      root-only file first and fed to `sudo -S` from there, which never
#      touches the script's own stdin.
#
# Usage:
#   .\vm-run.ps1 provision-stack.sh
#   .\vm-run.ps1 -Script ..\..\scripts\thing.sh

param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Script,

    [string]$TargetHost = "192.168.1.51",
    [string]$User = "leechuihui",
    [string]$Password = "LabPass123!"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $Script)) {
    Write-Error "script not found: $Script"
    exit 1
}

$full = (Resolve-Path $Script).Path
$raw = Get-Content $full -Raw

# Normalise to LF, then base64. Both steps together make the transport safe.
$raw = $raw -replace "`r`n", "`n" -replace "`r", "`n"
$bytes = [System.Text.Encoding]::UTF8.GetBytes($raw)
$b64 = [System.Convert]::ToBase64String($bytes)

# --- askpass helper --------------------------------------------------------
$helperDir = Join-Path $env:TEMP "umbra-askpass"
if (-not (Test-Path $helperDir)) {
    New-Item -ItemType Directory -Path $helperDir -Force | Out-Null
}
$helper = Join-Path $helperDir "askpass.cmd"
Set-Content -Path $helper -Value "@echo off`r`necho $Password" -Encoding ASCII

$env:SSH_ASKPASS = $helper
$env:SSH_ASKPASS_REQUIRE = "force"
$env:DISPLAY = "dummy:0"

# --- remote command --------------------------------------------------------
# 1. decode the script to /tmp/umbra-run.sh
# 2. write the sudo password to a root-only file
# 3. run the script with bash
$remote = @(
    "set -e"
    "printf '%s' '$b64' | base64 -d > /tmp/umbra-run.sh"
    "chmod 700 /tmp/umbra-run.sh"
    "printf '%s\n' '$Password' > /tmp/.umbra-pw"
    "chmod 600 /tmp/.umbra-pw"
    "bash /tmp/umbra-run.sh"
    "rc=`$?"
    "rm -f /tmp/.umbra-pw"
    "exit `$rc"
) -join " && "

$sshArgs = @(
    "-o", "StrictHostKeyChecking=no",
    "-o", "UserKnownHostsFile=NUL",
    "-o", "PreferredAuthentications=password",
    "-o", "PubkeyAuthentication=no",
    "-o", "ConnectTimeout=15",
    "-o", "LogLevel=ERROR",
    "$User@$TargetHost",
    $remote
)

& ssh @sshArgs 2>&1 | ForEach-Object { $_ }

exit $LASTEXITCODE
