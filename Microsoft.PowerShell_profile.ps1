Set-ExecutionPolicy Unrestricted -Scope CurrentUser
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

<#
write a powershell script that very specifically:

1. takes an argument, PEName
2. takes an argument, export
3. takes an argument, optional, wow (/wow)
4. looks through directory C:\Windows, C:\Windows\System32 (in this case, if /wow, then C:\Windows\SysWOW64) -- remember these as SearchPath variables
5. uses select-object -like * for wildcard pattern matching, over all *files* in folder, to see if they match the patter in in "PEName"
6. saves all files
7. goes through all files using dumpbin /EXPORTS (here a string using both searchpaths + files found) then the PE name
8. store the result of that and check $? for True. if False, then don't record
9. get the command's output, then using select-object filter for -like * for the exports string to use wildcard pattern matching
10. store in result string for file like "(full path): (newline) (results per line)"
11. print all of these
#>
function Find-PEExports {
    param(
        [Parameter(Mandatory = $true)]
        [string]$PEName,

        [Parameter(Mandatory = $true)]
        [string]$Export,

        [switch]$wow
    )

    # Check if dumpbin is in PATH
    $DumpbinPath = Get-Command dumpbin -ErrorAction SilentlyContinue
    if (-not $DumpbinPath) {
        Write-Error "'dumpbin' was not found in your system PATH. Please run from a Developer Command Prompt or add it to PATH."
        return
    }

    # Set search paths
    $SearchPaths = @("C:\Windows", "C:\Windows\System32")
    if ($wow) {
        $SearchPaths = @("C:\Windows", "C:\Windows\SysWOW64")
    }

    $Results = @()

    foreach ($Path in $SearchPaths) {
        # Get matching files based on PEName pattern (only top-level files)
        $Files = Get-ChildItem -Path $Path -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "*$PEName*" }

        foreach ($File in $Files) {
            # Run dumpbin /EXPORTS on the file
            $Output = & dumpbin /EXPORTS "`"$($File.FullName)`"" 2>&1

            # Only continue if dumpbin succeeded
            if ($?) {
                # Filter for lines that match the Export pattern
                $FilteredLines = $Output | Where-Object { $_ -like "*$Export*" }

                if ($FilteredLines.Count -gt 0) {
                    # Format the result
                    $Result = "$($File.FullName):`n$($FilteredLines -join "`n")"
                    $Results += $Result
                }
            }
        }
    }

    # Output all results
    $Results | ForEach-Object { Write-Output $_ }
}
