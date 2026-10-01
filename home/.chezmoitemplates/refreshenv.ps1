# Reload environment variables from the registry into the current process, so
# changes made earlier (by an installer, or by another process) are visible
# without restarting the shell.
function Update-SessionEnvironment {
    # These are process-specific; the registry values belong to SYSTEM or are
    # composed by PowerShell itself.
    $skip = @('Path', 'PSModulePath', 'USERNAME', 'PROCESSOR_ARCHITECTURE')

    foreach ($scope in @('Machine', 'User')) {
        $variables = [Environment]::GetEnvironmentVariables($scope)
        foreach ($name in $variables.Keys) {
            if ($skip -notcontains $name) {
                Set-Item -Path "Env:$name" -Value $variables[$name]
            }
        }
    }

    # Machine entries first, then user entries, then anything that only exists
    # in this process (e.g. fnm's per-shell directory).
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
