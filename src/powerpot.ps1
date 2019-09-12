<#
.SYNOPSIS
    Fake honeypot written in pure Powershell
.DESCRIPTION
    Create a honeypot that simulates the processes of the most famous debuggers.
    In addition, it opens and monitors the most commonly attacked ports.
.PARAMETER  Start
    Start all the jobs. It cannot be used in front of the Stop parameter
.PARAMETER  Stop
    Stop all the jobs
.PARAMETER  Yes
    Accept all the prompts
.EXAMPLE
    .\powerpot.ps1 -Start
    Start the program
.EXAMPLE
    .\powerpot.ps1 -Start -Verbose
    Start the program in verbose mode
.EXAMPLE
    .\powerpot.ps1 -Stop -Yes
    Stop the program without showing prompts
.LINK
    Github: https://github.com/CosasDePuma/PowerPot
.NOTES
    Authors: Kike Fontan (@CosasDePuma) <kikefontanlorenzo@gmail.com>
    References: 
        https://github.com/Pwdrkeg/honeyport
        https://github.com/kinomakino/ps_socket_firewall
#>

Param(
    [CmdletBinding()]

    [Parameter(Mandatory=$true, ParameterSetName="Start")]
    [Switch]$Start,

    [Parameter(Mandatory=$true, ParameterSetName="Stop")]
    [Switch]$Stop,

    [Parameter(Mandatory=$false, ParameterSetName="Start")]
    [Parameter(Mandatory=$false, ParameterSetName="Stop")]
    [Switch]$Yes
)

Function Set-Configuration
{
    # System32 location
    $global:system32 = [Environment]::SystemDirectory
}

Function New-TempFolder
{
    # Temp folder
    $newGuid = [System.Guid]::NewGuid().toString()
    $global:tempFolder = Join-Path $env:temp -ChildPath $newGuid
    New-Item -Type Directory -Path $global:tempFolder | out-null
    Write-Verbose -Message "[+] Temp folder created at $global:tempFolder"
}

<# -----------
    PROCESSES
   ----------- #>

Function Set-ProcessConfiguration
{
    # Sandbox processes
    $global:sandboxProcesses = @(
        "idag",
        "idaq",
        "ImmunityDebugger"
        "ollydbg",
        "procmon",
        "VBoxService",
        "VBoxTray",
        "vmacthlp",
        "vmware-tray",
        "WinDbg",
        "wireshark"
    ) | ForEach-Object { "$_.exe" }

    # Ping location
    $global:pingLocation = Join-Path $global:system32 "ping.exe"
}

Function Start-Processes
{
    Write-Host -ForegroundColor Green "[+] Starting processes"

    ForEach ($process In $global:sandboxProcesses)
    {
        # Copy ping.exe as another program
        $binaryLocation = Join-Path $global:tempFolder $process
        Copy-Item $global:pingLocation $binaryLocation

        # Start the process pinging one time per hour
        Write-Verbose "[*] Spawning $process"
        Start-Process $binaryLocation -WindowStyle Hidden -ArgumentList "-t -w 3600000 -4 127.0.0.1"
    }
}

Function Stop-Processes
{
    Write-Host -ForegroundColor Green "[+] Stopping all the processes..."

    ForEach ($process In $global:sandboxProcesses)
    {
        # Kill the process
        Write-Verbose -Message "[*] Killing $process..."
        Stop-Process -ProcessName $process.Substring(0, $process.Length - 4) -ErrorAction SilentlyContinue
    }
}

<# -----------
     SOCKETS
   ----------- #>

Function Set-SocketConfiguration
{
    # Common ports
    $global:commonPorts = @(
        20, 21, 22, 23, 25, 80, 443
    )

    # Process name
    $global:socketProcessName = "SocketManager.exe"

    # Powershell location
    $global:powershellLocation = Join-Path $global:system32 -ChildPath "WindowsPowershell" | Join-Path -ChildPath "v1.0" | Join-Path -ChildPath "powershell.exe"
}

Function Start-Sockets
{
    # Copy powershell.exe as another program
    $binaryLocation = Join-Path $global:tempFolder $global:socketProcessName
    Copy-Item $global:powershellLocation $binaryLocation

    # Start the process open all the common ports
    Write-Host -ForegroundColor Green "[+] Starting sockets"
    $command = "ForEach (`$port In @($($global:commonPorts -Join ','))) {" +
        "`$socket = [System.Net.Sockets.TcpListener][int]`$port; Try { `$socket.Start() } Catch {} }" +
        "While (`$True) { Start-Sleep -Seconds 3600 }"
    
    Start-Process $binaryLocation -WindowStyle Hidden -ArgumentList "-NoExit -Command $command"
    Write-Verbose -Message "[*] Open ports: $global:commonPorts"
}

Function Stop-Sockets
{
    # Stop the sockets
    Write-Host -ForegroundColor Green "[+] Stopping all the sockets..."
    Write-Verbose -Message "[*] Killing $global:socketProcessName..."
    Stop-Process -ProcessName $global:socketProcessName.Substring(0, $global:socketProcessName.Length - 4) -ErrorAction SilentlyContinue
}

<# -----------
     PROGRAM
   ----------- #>

Function Exit-MainProgram
{
    Write-Host -ForegroundColor Blue "[*] Press any key to close..."
    cmd /c "pause" | out-null 
}

Function Start-MainProgram
{
    Set-Configuration
    Set-SocketConfiguration
    Set-ProcessConfiguration

    If ($Start)
    {
        New-TempFolder
        Start-Sockets
        Start-Processes
    }
    ElseIf ($Stop)
    {
        Stop-Sockets
        Stop-Processes
    }
    
    If (-Not $Yes)
    {
        Exit-MainProgram
    }
}
Start-MainProgram