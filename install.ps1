# Set up a Windows machine from these dotfiles with a single command:
#
#   irm https://raw.githubusercontent.com/wiztral/dotfiles/main/install.ps1 | iex
#
# Works on Windows PowerShell 5.1 and later. Run it from a normal
# (non-elevated) PowerShell window. It is safe to re-run: steps that are
# already done are skipped, and an existing checkout is updated instead of
# re-initialised.
#
# Optional environment variables:
#   DOTFILES_REPO    GitHub user or repo to initialise from (default: wiztral)
#   DOTFILES_BRANCH  branch to check out on first initialisation

function Invoke-DotfilesBootstrap {
    $ErrorActionPreference = 'Stop'
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

    $repo = if ($env:DOTFILES_REPO) { $env:DOTFILES_REPO } else { 'wiztral' }
    $branch = $env:DOTFILES_BRANCH
    $keyPath = Join-Path $HOME '.ssh\id_ed25519'
    $notes = New-Object System.Collections.Generic.List[string]

    function Write-Step($message) {
        Write-Host ''
        Write-Host "==> $message" -ForegroundColor Cyan
    }

    function Test-Command($name) {
        [bool](Get-Command $name -ErrorAction SilentlyContinue)
    }

    # Keep in sync with home/.chezmoitemplates/refreshenv.ps1. This copy exists
    # because the bootstrap runs before the repository is available.
    function Update-SessionEnvironment {
        $skip = @('Path', 'PSModulePath', 'USERNAME', 'PROCESSOR_ARCHITECTURE')

        foreach ($scope in @('Machine', 'User')) {
            $variables = [Environment]::GetEnvironmentVariables($scope)
            foreach ($name in $variables.Keys) {
                if ($skip -notcontains $name) {
                    Set-Item -Path "Env:$name" -Value $variables[$name]
                }
            }
        }

        $entries = @(
            [Environment]::GetEnvironmentVariable('Path', 'Machine')
            [Environment]::GetEnvironmentVariable('Path', 'User')
            $env:Path
        ) -split ';' | Where-Object { $_ }

        $seen = @{}
        $path = foreach ($entry in $entries) {
            $key = $entry.TrimEnd('\').ToLowerInvariant()
            if (-not $seen.ContainsKey($key)) {
                $seen[$key] = $true
                $entry
            }
        }
        $env:Path = $path -join ';'
    }

    function Get-RegistryValue($path, $name) {
        $item = Get-ItemProperty -Path $path -ErrorAction SilentlyContinue
        if ($item -and $item.PSObject.Properties[$name]) { $item.$name }
    }

    function Test-DeveloperMode {
        (Get-RegistryValue 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock' 'AllowDevelopmentWithoutDevLicense') -eq 1
    }

    function Test-LongPaths {
        (Get-RegistryValue 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem' 'LongPathsEnabled') -eq 1
    }

    function Test-SshAgent {
        $service = Get-Service -Name ssh-agent -ErrorAction SilentlyContinue
        $service -and $service.StartType -eq 'Automatic' -and $service.Status -eq 'Running'
    }

    function Install-Scoop {
        if (Test-Command scoop) { return }
        # In a child process, because the installer calls `exit` on failure.
        powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression"
        Update-SessionEnvironment
        if (-not (Test-Command scoop)) { throw 'Scoop installation failed.' }
    }

    # Prefer the OpenSSH that ships with Windows: its ssh-agent service is the
    # one enabled below, and the one .gitconfig points git at.
    function Get-SshTool($name) {
        $builtin = Join-Path $env:WINDIR "System32\OpenSSH\$name.exe"
        if (Test-Path $builtin) { return $builtin }
        $command = Get-Command $name -ErrorAction SilentlyContinue
        if ($command) { return $command.Source }
    }

    # Native commands write progress to stderr, which Windows PowerShell turns
    # into terminating errors when redirected under $ErrorActionPreference = 'Stop'.
    function Invoke-Quiet([scriptblock]$command) {
        $ErrorActionPreference = 'Continue'
        (& $command 2>&1 | Out-String)
    }

    function Test-GitHubSsh($ssh) {
        $output = Invoke-Quiet { & $ssh -T -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 git@github.com }
        $output -match 'successfully authenticated'
    }

    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $isAdmin = (New-Object Security.Principal.WindowsPrincipal $identity).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if ($isAdmin) {
        throw 'Run this from a normal (non-elevated) PowerShell window. Scoop refuses to install as administrator; the steps that need elevation ask for it themselves.'
    }

    # --- 1. Questions, all up front ------------------------------------------

    Write-Step 'A few questions before the unattended part'

    $name = $null
    $email = $null
    $configured = Test-Path (Join-Path $HOME '.config\chezmoi\chezmoi.toml')
    if ($configured) {
        Write-Host 'chezmoi is already configured; keeping the existing name and email.'
    } else {
        while (-not $name) { $name = (Read-Host 'Your name').Trim() }
        while (-not $email) { $email = (Read-Host 'Your email address').Trim() }
    }

    $passphrase = $null
    $generateKey = -not (Test-Path $keyPath)
    if ($generateKey) {
        while ($null -eq $passphrase) {
            $first = (New-Object Net.NetworkCredential('', (Read-Host 'Passphrase for a new SSH key (empty for none)' -AsSecureString))).Password
            $second = (New-Object Net.NetworkCredential('', (Read-Host 'Repeat the passphrase' -AsSecureString))).Password
            if ($first -ceq $second) { $passphrase = $first } else { Write-Host 'Passphrases do not match, try again.' -ForegroundColor Yellow }
        }
    } else {
        Write-Host "SSH key already exists at $keyPath; keeping it."
    }

    # --- 2. Execution policy --------------------------------------------------

    Write-Step 'Execution policy'
    if (@('RemoteSigned', 'Unrestricted', 'Bypass') -contains (Get-ExecutionPolicy -Scope CurrentUser)) {
        Write-Host 'Already allows local scripts.'
    } else {
        try {
            Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
            Write-Host 'Set to RemoteSigned for the current user.'
        } catch {
            # Typically a group policy at a more specific scope.
            $notes.Add("Execution policy could not be set to RemoteSigned: $($_.Exception.Message)")
        }
    }

    # --- 3. PowerShell 7 ------------------------------------------------------

    Write-Step 'PowerShell 7'
    if (Test-Command pwsh) {
        Write-Host 'Already installed.'
    } else {
        if (-not (Test-Command winget)) {
            # App Installer is present on Windows 11 but may not be registered
            # yet for a brand-new user profile.
            try {
                Add-AppxPackage -RegisterByFamilyName -MainPackage Microsoft.DesktopAppInstaller_8wekyb3d8bbwe
                Update-SessionEnvironment
            } catch {
                Write-Host "winget is not available: $($_.Exception.Message)" -ForegroundColor Yellow
            }
        }

        if (Test-Command winget) {
            winget install --id Microsoft.PowerShell --source winget --silent --accept-source-agreements --accept-package-agreements
            Update-SessionEnvironment
        }

        if (-not (Test-Command pwsh)) {
            Write-Host 'Falling back to Scoop for PowerShell 7.' -ForegroundColor Yellow
            Install-Scoop
            scoop install pwsh
            Update-SessionEnvironment
        }

        if (-not (Test-Command pwsh)) { throw 'PowerShell 7 could not be installed.' }
    }

    # --- 4. Settings that need administrator rights ---------------------------

    Write-Step 'System settings (Developer Mode, long paths, ssh-agent)'
    if ((Test-DeveloperMode) -and (Test-LongPaths) -and (Test-SshAgent)) {
        Write-Host 'Already configured.'
    } else {
        $elevatedScript = Join-Path $env:TEMP "dotfiles-elevated-$PID.ps1"
        @'
$key = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock'
try {
    if (-not (Test-Path $key)) { New-Item -Path $key | Out-Null }
    Set-ItemProperty -Path $key -Name AllowDevelopmentWithoutDevLicense -Value 1 -Type DWord
} catch { Write-Warning "Developer Mode: $_" }

try {
    Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem' -Name LongPathsEnabled -Value 1 -Type DWord
} catch { Write-Warning "Long paths: $_" }

try {
    Set-Service -Name ssh-agent -StartupType Automatic
    Start-Service -Name ssh-agent
} catch { Write-Warning "ssh-agent: $_" }
'@ | Set-Content -Path $elevatedScript -Encoding ASCII

        try {
            Write-Host 'Requesting administrator rights (one prompt)...'
            Start-Process -FilePath powershell.exe -Verb RunAs -Wait -WindowStyle Hidden `
                -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$elevatedScript`"")
        } catch {
            Write-Host "Elevation was declined or failed: $($_.Exception.Message)" -ForegroundColor Yellow
        } finally {
            Remove-Item -Path $elevatedScript -ErrorAction SilentlyContinue
        }

        # Report from the resulting state rather than from the child's exit
        # code, so partial success is described accurately.
        if (-not (Test-DeveloperMode)) { $notes.Add('Developer Mode is not enabled (needs administrator rights). Enable it under Settings > System > For developers.') }
        if (-not (Test-LongPaths)) { $notes.Add('Long paths are not enabled (needs administrator rights): set LongPathsEnabled=1 under HKLM\SYSTEM\CurrentControlSet\Control\FileSystem.') }
        if (-not (Test-SshAgent)) { $notes.Add('The ssh-agent service is not set to start automatically (needs administrator rights): Set-Service ssh-agent -StartupType Automatic; Start-Service ssh-agent') }
    }

    # --- 5. chezmoi -----------------------------------------------------------

    Write-Step 'chezmoi'
    $binDir = Join-Path $HOME 'bin'
    if (-not (Test-Command chezmoi) -and (Test-Path (Join-Path $binDir 'chezmoi.exe'))) {
        $env:Path = "$env:Path;$binDir"
    }
    if (-not (Test-Command chezmoi)) {
        & ([scriptblock]::Create((Invoke-RestMethod -Uri 'https://get.chezmoi.io/ps1'))) -BinDir $binDir
        $env:Path = "$env:Path;$binDir"
        if (-not (Test-Command chezmoi)) { throw 'chezmoi installation failed.' }
    }

    $sourceDir = Join-Path $HOME '.local\share\chezmoi'
    if (Test-Path (Join-Path $sourceDir '.git')) {
        Write-Host "Updating the existing checkout in $sourceDir"
        chezmoi update --init
    } else {
        $initArgs = @('init', '--apply')
        if ($branch) { $initArgs += @('--branch', $branch) }
        if ($name) { $initArgs += @('--promptString', "Your name=$name", '--promptString', "Your email address=$email") }
        chezmoi @initArgs $repo
    }
    if ($LASTEXITCODE -ne 0) { throw "chezmoi failed with exit code $LASTEXITCODE" }

    Update-SessionEnvironment

    # --- 6. SSH key and GitHub ------------------------------------------------

    Write-Step 'SSH key'
    $ssh = Get-SshTool 'ssh'
    $sshKeygen = Get-SshTool 'ssh-keygen'
    $sshAdd = Get-SshTool 'ssh-add'

    if (-not ($ssh -and $sshKeygen -and $sshAdd)) {
        $notes.Add('OpenSSH client was not found, so no SSH key was set up. Install it under Settings > System > Optional features, then re-run this script.')
    } else {
        if ($generateKey) {
            if (-not $email) { $email = (chezmoi execute-template '{{ .user.email }}') }
            New-Item -ItemType Directory -Path (Split-Path $keyPath) -Force | Out-Null

            # An empty argument is dropped by the legacy native argument
            # passing of Windows PowerShell, so it has to be spelled as "".
            $legacyArgs = $PSVersionTable.PSVersion.Major -lt 7 -or "$PSNativeCommandArgumentPassing" -eq 'Legacy'
            $passphraseArg = if ($passphrase -eq '' -and $legacyArgs) { '""' } else { $passphrase }
            & $sshKeygen -q -t ed25519 -C $email -f $keyPath -N $passphraseArg
            if ($LASTEXITCODE -ne 0) { throw "ssh-keygen failed with exit code $LASTEXITCODE" }
            Write-Host "Created $keyPath"

            if (Test-SshAgent) {
                # Hand the passphrase to ssh-add through SSH_ASKPASS so it is
                # not asked for a second time.
                $askpass = Join-Path $env:TEMP "dotfiles-askpass-$PID.cmd"
                '@powershell.exe -NoProfile -Command "[Console]::Out.Write($env:DOTFILES_SSH_PASSPHRASE)"' | Set-Content -Path $askpass -Encoding ASCII
                try {
                    $env:DOTFILES_SSH_PASSPHRASE = $passphrase
                    $env:SSH_ASKPASS = $askpass
                    $env:SSH_ASKPASS_REQUIRE = 'force'
                    $null = Invoke-Quiet { & $sshAdd $keyPath }
                    $added = $LASTEXITCODE -eq 0
                } finally {
                    Remove-Item Env:DOTFILES_SSH_PASSPHRASE, Env:SSH_ASKPASS, Env:SSH_ASKPASS_REQUIRE -ErrorAction SilentlyContinue
                    Remove-Item -Path $askpass -ErrorAction SilentlyContinue
                }
                if (-not $added) {
                    # Older OpenSSH builds ignore SSH_ASKPASS; ask directly.
                    & $sshAdd $keyPath
                    $added = $LASTEXITCODE -eq 0
                }
                if (-not $added) { $notes.Add("The new key could not be added to ssh-agent. Run: ssh-add $keyPath") }
            }
        }

        $authenticated = Test-GitHubSsh $ssh
        if (-not $authenticated) {
            $publicKey = (Get-Content -Path "$keyPath.pub" -Raw).Trim()
            Set-Clipboard -Value $publicKey
            Write-Host ''
            Write-Host 'Add this public key to GitHub (it is on the clipboard):' -ForegroundColor Yellow
            Write-Host '  https://github.com/settings/ssh/new'
            Write-Host ''
            Write-Host $publicKey
            Write-Host ''
            while (-not $authenticated) {
                $answer = Read-Host "Press Enter once the key is added, or type 'skip'"
                if ($answer.Trim() -eq 'skip') { break }
                $authenticated = Test-GitHubSsh $ssh
                if (-not $authenticated) { Write-Host 'GitHub did not accept the key yet.' -ForegroundColor Yellow }
            }
        }

        if ($authenticated) {
            Write-Host 'GitHub accepts the SSH key.'
            if (Test-Command git) {
                $origin = (git -C $sourceDir remote get-url origin)
                if ($origin -match '^https://github\.com/(.+?)(\.git)?/?$') {
                    $sshUrl = "git@github.com:$($Matches[1]).git"
                    git -C $sourceDir remote set-url origin $sshUrl
                    Write-Host "Dotfiles remote switched to $sshUrl"
                }
            } else {
                $notes.Add('git was not found, so the dotfiles remote is still HTTPS.')
            }
        } else {
            $notes.Add("GitHub does not accept the SSH key yet. Add $keyPath.pub at https://github.com/settings/ssh/new and re-run this script to switch the dotfiles remote to SSH.")
        }
    }

    # --- 7. Summary -----------------------------------------------------------

    Write-Step 'Done'
    $notes.Add('WSL is not set up by this script. Install it with "wsl --install -d Ubuntu" from an elevated prompt, reboot, then run the Linux one-liner from the README inside it.')
    $notes.Add('Open a new terminal to pick up PATH and environment changes (or run "refreshenv" in an existing PowerShell 7 window).')

    Write-Host 'Left for you to do:'
    foreach ($note in $notes) { Write-Host "  - $note" }
}

Invoke-DotfilesBootstrap
