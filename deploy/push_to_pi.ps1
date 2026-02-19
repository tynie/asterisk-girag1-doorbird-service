param(
  [string]$PiHost = "192.168.11.180",
  [string]$PiUser = "config",
  [string]$KeyPath = "C:\Users\admin\Documents\codex\doorbird-g1-bridge\key2"
)

$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path -Parent $PSScriptRoot
$SshExe = "C:\Windows\System32\OpenSSH\ssh.exe"
$ScpExe = "C:\Windows\System32\OpenSSH\scp.exe"
$Remote = "$PiUser@$PiHost"

function Copy-ToPi([string]$LocalPath, [string]$RemotePath) {
  & $ScpExe -i $KeyPath $LocalPath "$Remote`:$RemotePath"
}

Write-Host "[1/4] copy asterisk configs"
Copy-ToPi "$RepoRoot\asterisk18\sip_doorbird_test.conf" "/home/config/sip_doorbird_test.conf"
Copy-ToPi "$RepoRoot\asterisk18\extensions_doorbird_test.conf" "/home/config/extensions_doorbird_test.conf"
Copy-ToPi "$RepoRoot\asterisk18\confbridge_doorbird_test.conf" "/home/config/confbridge_doorbird_test.conf"
Copy-ToPi "$RepoRoot\asterisk18\apply18.sh" "/home/config/apply18.sh"

Write-Host "[2/4] copy service/scripts"
Copy-ToPi "$RepoRoot\scripts\doorbird-preview-live.service" "/home/config/doorbird-preview-live.service"
Copy-ToPi "$RepoRoot\scripts\pi_baresip_preview_call.sh" "/home/config/pi_baresip_preview_call.sh"
Copy-ToPi "$RepoRoot\scripts\pi_baresip_preview_dual_live.sh" "/home/config/pi_baresip_preview_dual_live.sh"
Copy-ToPi "$RepoRoot\scripts\doorbird_conf_guard.sh" "/home/config/doorbird_conf_guard.sh"
Copy-ToPi "$RepoRoot\deploy\install_solution_on_pi.sh" "/home/config/install_solution_on_pi.sh"
Copy-ToPi "$RepoRoot\deploy\bootstrap_pi_bookworm.sh" "/home/config/bootstrap_pi_bookworm.sh"

Write-Host "[3/4] copy baresip template + env example"
Copy-ToPi "$RepoRoot\assets\baresip-doorbirdtest\config" "/home/config/baresip-doorbirdtest.config"
Copy-ToPi "$RepoRoot\assets\baresip-doorbirdtest\accounts" "/home/config/baresip-doorbirdtest.accounts"
Copy-ToPi "$RepoRoot\assets\baresip-doorbirdtest\contacts" "/home/config/baresip-doorbirdtest.contacts"
Copy-ToPi "$RepoRoot\doorbird.local.env.example" "/home/config/doorbird.local.env.example"

Write-Host "[4/4] run installer + verify"
$RemoteCmd = @"
set -e
sudo -n chmod 755 /home/config/apply18.sh /home/config/install_solution_on_pi.sh /home/config/bootstrap_pi_bookworm.sh
sudo -n bash /home/config/install_solution_on_pi.sh
sudo -n /opt/asterisk18-test/sbin/asterisk -C /opt/asterisk18-test/etc/asterisk/asterisk.conf -rx 'sip show peers'
sudo -n /opt/asterisk18-test/sbin/asterisk -C /opt/asterisk18-test/etc/asterisk/asterisk.conf -rx 'dialplan show 7800@doorbird-in'
"@
& $SshExe -i $KeyPath -o BatchMode=yes -o ConnectTimeout=8 $Remote $RemoteCmd

Write-Host "Deploy complete."
