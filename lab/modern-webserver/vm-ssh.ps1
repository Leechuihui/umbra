# Run a command inside the modern webserver VM over SSH.
#
# The VM is a Debian cloud image with password auth enabled by cloud-init.
# sshpass is not available on Windows, so we use OpenSSH's SSH_ASKPASS helper:
# OpenSSH executes the helper program to obtain the password instead of
# reading from a terminal.
#
# Usage:
#   .\vm-ssh.ps1 "id; hostname"
#   .\vm-ssh.ps1 -TargetHost 192.168.1.51 "systemctl status nginx"

param(
    [string]$TargetHost = "192.168.1.51",
    [string]$User = "root",
    [string]$Password = "LabPass123!",
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Command
)

$ErrorActionPreference = "Stop"

# --- build an askpass helper that just echoes the password -----------------
$helperDir = Join-Path $env:TEMP "umbra-askpass"
if (-not (Test-Path $helperDir)) {
    New-Item -ItemType Directory -Path $helperDir -Force | Out-Null
}

$helper = Join-Path $helperDir "askpass.cmd"
Set-Content -Path $helper -Value "@echo off`r`necho $Password" -Encoding ASCII

# --- run ssh ---------------------------------------------------------------
$env:SSH_ASKPASS = $helper
$env:SSH_ASKPASS_REQUIRE = "force"
$env:DISPLAY = "dummy:0"

$sshArgs = @(
    "-o", "StrictHostKeyChecking=no",
    "-o", "UserKnownHostsFile=NUL",
    "-o", "PreferredAuthentications=password",
    "-o", "PubkeyAuthentication=no",
    "-o", "ConnectTimeout=15",
    "-o", "LogLevel=ERROR",
    "$User@$TargetHost",
    $Command
)

$output = & ssh @sshArgs 2>&1
$code = $LASTEXITCODE

$output | ForEach-Object { $_ }

if ($code -ne 0) {
    Write-Output "[ssh exit code: $code]"
}
exit $code
