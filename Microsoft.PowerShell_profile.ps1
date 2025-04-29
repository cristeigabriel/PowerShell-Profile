# Execution
Set-ExecutionPolicy Unrestricted -Scope CurrentUser

# Browse history across all sessions using Microsoft query-style strings
function hist {
    $find = $args -join ' '

    # Get all known names/aliases for the 'hist' function
    $histCommandNames = @()
    $command = Get-Command hist -ErrorAction SilentlyContinue
    if ($command) {
        $histCommandNames += $command.Name
        if ($command.CommandType -eq 'Function') {
            $histCommandNames += (Get-Alias | Where-Object { $_.Definition -eq 'hist' }).Name
        }
    }

    Write-Host "Finding in full history using {`$_ -like `"*$find*`"}"
    Get-Content (Get-PSReadlineOption).HistorySavePath |
        Where-Object {
            $_ -like "*$find*" -and
            ($histCommandNames -notcontains ($_ -split '\s+')[0])
        } |
        Get-Unique |
        more
}
