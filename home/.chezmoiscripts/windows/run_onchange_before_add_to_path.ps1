Set-StrictMode -Version 3.0

# Define the path to add
$NewPath = "$env:USERPROFILE\quick-cmds"

# Normalize slashes and remove trailing slash if present
$NewPath = $NewPath -replace '/', '\' # Convert forward slashes to backslashes
$NewPath = $NewPath.TrimEnd('\\')

# Get the current user PATH environment variable
$CurrentPath = [System.Environment]::GetEnvironmentVariable("Path", "User")

$CurrentPathList = $CurrentPath -split ";" | ForEach-Object { ($_ -replace '/', '\').TrimEnd('\\') }

# Check if the new path is already in the PATH variable
if ($CurrentPathList -notcontains $NewPath) {
    # Append the new path
    $CurrentPath = $CurrentPath.TrimEnd(';')
    $UpdatedPath = "$CurrentPath;$NewPath;"

    # Update the user PATH environment variable
    [System.Environment]::SetEnvironmentVariable("Path", $UpdatedPath, "User")
    
    Write-Output "Path added successfully. Please restart your session for changes to take effect."
} else {
    Write-Output "Path already exists in the user PATH variable."
}
