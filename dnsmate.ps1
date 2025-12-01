Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Output "DNSMate needs to be run as Administrator. Attempting to relaunch."

    $script = if ($PSCommandPath) {
        "& { & `'$($PSCommandPath)`' }"
    } else {
        "&([ScriptBlock]::Create((irm https://raw.githubusercontent.com/xeptore/dnsmate/refs/heads/main/dnsmate.ps1)))"
    }

    $powershellCmd = if (Get-Command pwsh -ErrorAction SilentlyContinue) { "pwsh" } else { "powershell" }
    $processCmd = if (Get-Command wt.exe -ErrorAction SilentlyContinue) { "wt.exe" } else { "$powershellCmd" }

    if ($processCmd -eq "wt.exe") {
        Start-Process $processCmd -ArgumentList "$powershellCmd -ExecutionPolicy Bypass -NoProfile -Command `"$script`"" -Verb RunAs
    } else {
        Start-Process $processCmd -ArgumentList "-ExecutionPolicy Bypass -NoProfile -Command `"$script`"" -Verb RunAs
    }

    break
}

$Host.UI.RawUI.WindowTitle = "DNSMate (Admin)"
clear-host

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls13
$dnsProviders = Invoke-WebRequest 'https://raw.githubusercontent.com/xeptore/dnsmate/refs/heads/main/providers.json' | ConvertFrom-Json

# Get active network adapters
function Get-NetworkAdapters {
    $adapters = Get-NetAdapter | Where-Object { $_.Status -eq "Up" } | Sort-Object Name
    return $adapters
}

# Dark theme colors
$darkBg = [System.Drawing.Color]::FromArgb(32, 32, 32)
$darkControlBg = [System.Drawing.Color]::FromArgb(45, 45, 45)
$darkText = [System.Drawing.Color]::FromArgb(240, 240, 240)
$darkBorder = [System.Drawing.Color]::FromArgb(60, 60, 60)
$accentBlue = [System.Drawing.Color]::FromArgb(0, 122, 204)

# Create main form
$form = New-Object System.Windows.Forms.Form
$form.Text = "DNS Configuration Tool"
$form.Size = New-Object System.Drawing.Size(500, 300)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false
$form.MinimizeBox = $false
$form.BackColor = $darkBg
$form.ForeColor = $darkText

# DNS Provider Label
$lblDnsProvider = New-Object System.Windows.Forms.Label
$lblDnsProvider.Location = New-Object System.Drawing.Point(20, 20)
$lblDnsProvider.Size = New-Object System.Drawing.Size(200, 20)
$lblDnsProvider.Text = "Select DNS Provider:"
$lblDnsProvider.BackColor = $darkBg
$lblDnsProvider.ForeColor = $darkText
$form.Controls.Add($lblDnsProvider)

# DNS Provider Dropdown
$cmbDnsProvider = New-Object System.Windows.Forms.ComboBox
$cmbDnsProvider.Location = New-Object System.Drawing.Point(20, 45)
$cmbDnsProvider.Size = New-Object System.Drawing.Size(440, 25)
$cmbDnsProvider.DropDownStyle = "DropDownList"
$cmbDnsProvider.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$cmbDnsProvider.BackColor = $darkControlBg
$cmbDnsProvider.ForeColor = $darkText
$cmbDnsProvider.FlatStyle = "Popup"
foreach ($p in $dnsProviders.PSObject.Properties) {
    $cmbDnsProvider.Items.Add($p.Name) | Out-Null
}
$cmbDnsProvider.SelectedIndex = 0
$form.Controls.Add($cmbDnsProvider)

# Status Label
$lblStatus = New-Object System.Windows.Forms.Label
$lblStatus.Location = New-Object System.Drawing.Point(20, 80)
$lblStatus.Size = New-Object System.Drawing.Size(440, 90)
$lblStatus.Text = ""
$lblStatus.BackColor = $darkBg
$lblStatus.ForeColor = [System.Drawing.Color]::FromArgb(180, 180, 180)
$form.Controls.Add($lblStatus)

# Apply Button
$btnApply = New-Object System.Windows.Forms.Button
$btnApply.Location = New-Object System.Drawing.Point(20, 210)
$btnApply.Size = New-Object System.Drawing.Size(440, 35)
$btnApply.Text = "Apply DNS Settings"
$btnApply.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$btnApply.BackColor = $accentBlue
$btnApply.ForeColor = [System.Drawing.Color]::White
$btnApply.FlatStyle = "Flat"
$btnApply.FlatAppearance.BorderSize = 0
$btnApply.FlatAppearance.MouseOverBackColor = [System.Drawing.Color]::FromArgb(0, 102, 170)
$btnApply.Cursor = [System.Windows.Forms.Cursors]::Hand
$form.Controls.Add($btnApply)

# Button click event
$btnApply.Add_Click({
    if ($cmbDnsProvider.SelectedItem -eq $null) {
        $lblStatus.Text = "Please select both DNS provider and network adapter."
        $lblStatus.ForeColor = [System.Drawing.Color]::FromArgb(255, 100, 100)
        return
    }

    $selectedProvider = $cmbDnsProvider.SelectedItem.ToString()
    $dnsServer = $dnsProviders.$selectedProvider

    try {
        $lblStatus.Text = "Applying DNS settings..."
        $lblStatus.ForeColor = [System.Drawing.Color]::FromArgb(100, 180, 255)
        $btnApply.Enabled = $false
        $form.Refresh()

        $Adapters = Get-NetAdapter | Where-Object {$_.Status -eq "Up"}

        Foreach ($Adapter in $Adapters) {
            if($DNSProvider -eq "DHCP") {
                Set-DnsClientServerAddress -InterfaceIndex $Adapter.ifIndex -ResetServerAddresses
            } else {
                Set-DnsClientServerAddress -InterfaceIndex $Adapter.ifIndex -ServerAddresses ("$($dnsServer[0])", "$($dnsServer[1])")
            }
        }

        Clear-DnsClientCache

        $lblStatus.Text = @"
DNS settings applied successfully!
Provider: $selectedProvider
Adapters: $(($Adapters | Select-Object -ExpandProperty Name) -join ', ')
DNS Servers: $($dnsServer[0]) - $($dnsServer[1])
"@
        $lblStatus.ForeColor = [System.Drawing.Color]::FromArgb(100, 220, 100)
    }
    catch {
        $lblStatus.Text = "Error: $($_.Exception.Message)"
        $lblStatus.ForeColor = [System.Drawing.Color]::FromArgb(255, 100, 100)
    }
    finally {
        $btnApply.Enabled = $true
    }
})

# Show form
[System.Windows.Forms.Application]::Run($form)
