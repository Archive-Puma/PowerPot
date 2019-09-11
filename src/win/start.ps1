
Param(
    [CmdletBinding()]

    [Parameter(Mandatory=$true,
    ParameterSetName="Start")]
    [Switch]
    $Start,

    [Parameter(Mandatory=$true,
    ParameterSetName="Stop")]
    [Switch]
    $Stop
)

function Set-Configuration
{
    # Sandbox processes
    $global:sandboxProcesses = @(
        'idag',
        'idaq',
        'ImmunityDebugger'
        'ollydbg',
        'procmon',
        'VBoxService',
        'VBoxTray',
        'vmacthlp',
        'vmware-tray',
        'WinDbg',
        'wireshark'
    ) | ForEach-Object { "$_.exe" }

    # Current working directory
    $global:cwd = $pwd

    # Ping location
    $system32 = [Environment]::SystemDirectory
    $global:pingLocation = Join-Path $system32 "ping.exe"

    # Temp folder
    $newGuid = [System.Guid]::NewGuid().toString()
    $global:tempFolder = Join-Path $env:temp $newGuid
}

function Start-Processes
{
    # Create temp folder
    New-Item -Type Directory -Path $global:tempFolder | out-null

    ForEach ($process In $global:sandboxProcesses)
    {
        # Copy ping.exe as another program
        $binaryLocation = Join-Path $global:tempFolder $process
        Copy-Item $global:pingLocation $binaryLocation

        # Start the process pinging one time per hour
        Start-Process $binaryLocation -WindowStyle Hidden -ArgumentList "-t -w 3600000 -4 1.1.1.1"
        Write-Host -ForegroundColor Green "[+] Spawned $process"
    }
}

function Stop-Processes
{
    ForEach ($process In $global:sandboxProcesses)
    {
        Write-Host -ForegroundColor Yellow "[+] Killing $process..."
        Stop-Process -ProcessName $process.Substring(0, $process.Length - 4) -ErrorAction SilentlyContinue
    }
}

function Exit-MainProgram
{
    Write-Host -ForegroundColor Blue "[*] Press any key to close..."
    cmd /c "pause" | out-null 
}

function Start-MainProgram
{
    Set-Configuration
    If ($Start) { Start-Processes }
    ElseIf ($Stop) { Stop-Processes }
    Exit-MainProgram
}
Start-MainProgram