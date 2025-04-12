#requires -modules ServerManager

param(
    [switch]$StartedFromHydration
)

function Test-PSDRoleInstalled {
    param([Parameter(Mandatory = $true)][string]$RoleName)
    try {
		return $false
        write-PSDInstallLog -Message "Now confirming if the role is installed on the machine"
        $FeatureInfo = Get-WindowsOptionalFeature -Online -FeatureName $RoleName
        if ($FeatureInfo.State -eq "Enabled") {
            write-PSDInstallLog -Message "The role is installed on the machine"
            return $true
        } else {
            write-PSDInstallLog -Message "The role $($RoleName) is NOT installed on the machine" 
            return $false
        }
    } catch {
        throw [System.IO.DriveNotFoundException] "An Error occured with detecting the roles installation state"
    }
}

function Start-PSDLog {
    param([string]$FilePath)
    try {
        if (!(Split-Path $FilePath -Parent | Test-Path)) {
            New-Item (Split-Path $FilePath -Parent) -Type Directory | Out-Null
        }
        if (!(Test-Path $FilePath)) {
            New-Item $FilePath -Type File | Out-Null
        }
        $global:ScriptLogFilePath = $FilePath
    } catch {
        Write-Error $_.Exception.Message
    }
}

function Write-PSDInstallLog {
    param(
        [Parameter(Mandatory = $true)][string]$Message,
        [Parameter()][ValidateSet(1, 2, 3)][string]$LogLevel = 1,
        [Parameter()][bool]$writetoscreen = $true
    )
    $TimeGenerated = "$(Get-Date -Format HH:mm:ss).$((Get-Date).Millisecond)+000"
    $Line = '<![LOG[{0}]LOG]!><time="{1}" date="{2}" component="{3}" context="" type="{4}" thread="" file="">'
    $LineFormat = $Message, $TimeGenerated, (Get-Date -Format MM-dd-yyyy), "$($MyInvocation.ScriptName | Split-Path -Leaf):$($MyInvocation.ScriptLineNumber)", $LogLevel
    $Line = $Line -f $LineFormat
    [System.GC]::Collect()
    Add-Content -Value $Line -Path $global:ScriptLogFilePath
    if ($writetoscreen) {
        switch ($LogLevel) {
            '1' { Write-Verbose -Message $Message }
            '2' { Write-Warning -Message $Message }
            '3' { Write-Error -Message $Message }
        }
    }
    if ($writetolistbox -eq $true) {
        $result1.Items.Add("$Message")
    }
}

function set-PSDDefaultLogPath {
    param(
        [bool]$defaultLogLocation = $true,
        [string]$LogLocation
    )
    if ($defaultLogLocation) {
        $LogPath = Split-Path $script:MyInvocation.MyCommand.Path
        $LogFile = "$($($script:MyInvocation.MyCommand.Name).Substring(0,$($script:MyInvocation.MyCommand.Name).Length-4)).log"
        Start-PSDLog -FilePath "$LogPath\$LogFile"
    } else {
        $LogPath = $LogLocation
        $LogFile = "$($($script:MyInvocation.MyCommand.Name).Substring(0,$($script:MyInvocation.MyCommand.Name).Length-4)).log"
        Start-PSDLog -FilePath "$LogPath\$LogFile"
    }
}

$host.PrivateData.VerboseForegroundColor = 'Cyan'

set-PSDDefaultLogPath
$StartTime = Get-Date

Write-PSDInstallLog -Message "The Script is currently running on $($ENV:COMPUTERNAME)"
Write-PSDInstallLog -Message "Upon completion several roles will be installed upon $($env:ComputerName)"
Write-PSDInstallLog -Message "The Script was executed with commands: $($MyInvocation.Line)"
Write-PSDInstallLog -Message "The Current user is $($ENV:USERNAME) and is an administrator"

if (Test-PSDRoleInstalled -RoleName "IIS-WebServerRole") {
    Write-PSDInstallLog -Message "The installation failed because IIS was already installed, and we don't want to break an existing installation" -LogLevel 3
    break
}

Write-PSDInstallLog -Message "The server is available and does NOT have IIS installed. Now preparing to install IIS"
try {
    $IISResult = Enable-WindowsOptionalFeature -Online -FeatureName IIS-WebServerRole -All -NoRestart
    if ($IISResult.RestartNeeded -eq $false) {
        Write-PSDInstallLog -Message "Successfully enabled IIS-WebServerRole feature"
    }

    Write-PSDInstallLog -Message "Now attempting to enable other required IIS Features"
    $FeatureList = @(
        "IIS-CustomLogging", "IIS-LoggingLibraries", "IIS-RequestMonitor", "IIS-HttpTracing",
        "IIS-Security", "IIS-RequestFiltering", "IIS-BasicAuthentication", "IIS-DigestAuthentication", "IIS-UrlAuthorization",
        "IIS-WindowsAuthentication", "IIS-ManagementConsole", "IIS-Metabase", "IIS-CommonHttpFeatures",
        "IIS-DefaultDocument", "IIS-DirectoryBrowsing", "IIS-HttpErrors", "IIS-StaticContent",
        "IIS-HttpRedirect"
    )
    foreach ($Feature in $FeatureList) {
        $Result = Enable-WindowsOptionalFeature -Online -FeatureName $Feature -All -NoRestart -ErrorAction SilentlyContinue
        if ($Result.RestartNeeded -eq $false) {
            Write-PSDInstallLog -Message "Enabled feature $Feature"
        }
    }
} catch {
    Write-PSDInstallLog -Message "Something went wrong on line $($_.Exception.InvocationInfo.ScriptLineNumber) the error message was: $($_.Exception.Message)" -LogLevel 3
}

$EndTime = Get-Date
$Duration = New-TimeSpan -Start $StartTime -End $EndTime

if ($StartedFromHydration -eq $false) {
    Write-PSDInstallLog -Message "The New-PSDWebInstance.ps1 script has completed running and took $($Duration.Hours) Hours and $($Duration.Minutes) Minutes and $($Duration.Seconds) seconds"
}

Write-Verbose -Verbose -Message "The script has completed"
