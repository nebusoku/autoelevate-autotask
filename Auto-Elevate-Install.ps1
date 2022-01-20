<#
.SYNOPSIS
  Installs the AutoElevate agent using information from the Autotask Customer
  that this asset belongs to.
  
.DIRECTIONS
  Insert your license key below.  Change the default agent mode if you desire
  (audit, live, policy), and set the "Location Name" that will be used to
  "group" these assets.
#>

$LICENSE_KEY = ""

$API_USER_NAME = ''
$API_SECRET = ''
$API_INTEGRATION_CODE = '' #Datto Tracking Identifier

$AGENT_MODE = "audit"
$LOCATION_NAME = "Main Office" # FC: Default location name

# Set $DebugPrintEnabled = 1 to enabled debug log printing to see what's going on.
$DebugPrintEnabled = 1

# You don't need to change anything below this line...

$InstallerName = "AESetup.msi"
$InstallerPath = Join-Path $Env:TMP $InstallerName
$DownloadBase = "https://autoelevate-installers.s3.us-east-2.amazonaws.com"
$DownloadURL = $DownloadBase + "/current/" + $InstallerName
$ServiceName = "AutoElevateAgent"

$ScriptFailed = "Script Failed!"

function Get-TimeStamp {
    return "[{0:MM/dd/yy} {0:HH:mm:ss}]" -f (Get-Date)
}

function Confirm-ServiceExists ($service) {
    if (Get-Service $service -ErrorAction SilentlyContinue) {
        return $true
    }
    
    return $false
}

function Debug-Print ($msg) {
    if ($DebugPrintEnabled -eq 1) {
        Write-Host "$(Get-TimeStamp) [DEBUG] $msg"
    }
}

function Get-Installer {
    Debug-Print("Downloading installer...")
    $WebClient = New-Object System.Net.WebClient
    
    try {
        $WebClient.DownloadFile($DownloadURL, $InstallerPath)
    } catch {
        $ErrorMessage = $_.Exception.Message
        Write-Host "$(Get-TimeStamp) $ErrorMessage"
    }
    
    if ( ! (Test-Path $InstallerPath)) {
        $DownloadError = "Failed to download the AutoElevate Installer from $DownloadURL"
        Write-Host "$(Get-TimeStamp) $DownloadError"
        throw $ScriptFailed
    }
    
    Debug-Print("Installer downloaded to $InstallerPath...")
}

function Install-Agent () {
    Debug-Print("Checking for AutoElevateAgent service...")
    
    if (Confirm-ServiceExists($ServiceName)) {
        Write-Host "$(Get-TimeStamp) Service exists. Continuing with possible upgrade..."
    }
    else {
        Write-Host "$(Get-TimeStamp) Service does not exist. Continuing with initial installation..."
    }

    Debug-Print("Checking for installer file...")
    
    if ( ! (Test-Path $InstallerPath)) {
        $InstallerError = "The installer was unexpectedly removed from $InstallerPath"
        Write-Host "$(Get-TimeStamp) $InstallerError"
        Write-Host ("$(Get-TimeStamp) A security product may have quarantined the installer. Please check " +
                               "your logs. If the issue continues to occur, please send the log to the AutoElevate " +
                               "Team for help at support@autoelevate.com")
        throw $ScriptFailed
    }

    Debug-Print("Executing installer...")
    
    $Arguments = "/i {0} /quiet LICENSE_KEY=""{1}"" COMPANY_ID=""{2}"" COMPANY_NAME=""{3}"" LOCATION_NAME=""{4}"" AGENT_MODE=""{5}""" -f $InstallerPath, $LICENSE_KEY, $installationVariables.CompanyId, $installationVariables.CompanyName, $installationVariables.LocationName, $AGENT_MODE
    
    Start-Process C:\Windows\System32\msiexec.exe -ArgumentList $Arguments -Wait
}

function Verify-Installation () {
    Debug-Print("Verifying Installation...")
    
    if ( ! (Confirm-ServiceExists($ServiceName))) {
        $VerifiationError = "The AutoElevateAgent service is not running. Installation failed!"
        Write-Host "$(Get-TimeStamp) $VerificationError"
        
        throw $ScriptFailed
    }
}

function main () {
    Debug-Print("Checking for LICENSE_KEY...")
    
    if ($LICENSE_KEY -eq "__LICENSE_KEY_HERE__" -Or $LICENSE_KEY -eq "") {
        Write-Warning "$(Get-TimeStamp) LICENSE_KEY not set, exiting script!"
        exit 1
    }

    if ($installationVariables.CompanyId -eq "") {
        Write-Warning "$(Get-TimeStamp) company_id not specified, exiting script!"
        exit 1
    }
    
    if ($installationVariables.CompanyName -eq "") {
        Write-Warning "$(Get-TimeStamp) company_name not specified, exiting script!"
        exit 1
    }
    
    Write-Host "$(Get-TimeStamp) CompanyId: " $installationVariables.CompanyId
    Write-Host "$(Get-TimeStamp) CompanyName: " $installationVariables.CompanyName
    Write-Host "$(Get-TimeStamp) LocationName: " $installationVariables.LocationName
    Write-Host "$(Get-TimeStamp) AgentMode: " $AGENT_MODE
    
    Get-Installer
    Install-Agent
    Verify-Installation
    
    Write-Host "$(Get-TimeStamp) AutoElevate Agent successfully installed!"
}


function Get-Installation-Variables {
    $installationVariables = [pscustomobject]@{
        CompanyId    = $null
        CompanyName  = $null
        LocationName = $null
    }
    
    $configuration = Get-Configuration-By-Guid(Get-Guid)
    $installationVariables.CompanyId = $configuration.companyID.ToString()
    $installationVariables.CompanyName = Get-Company-Name-By-Id($installationVariables.CompanyId)

    if ($null -eq $configuration.companyLocationID) {
        $installationVariables.LocationName = $LOCATION_NAME
    }
    else {
        $installationVariables.LocationName = Get-Location-Name-By-Id($configuration.companyLocationID)
    }

    return $installationVariables
}

function Get-Configuration-By-Guid($guid) {
    $BaseUrl = Get-Zone-Information-Url
    Debug-Print($BaseUrl)
    Debug-Print($guid)
    $Uri = $BaseUrl + 'V1.0/ConfigurationItems/query?search={
        "filter":  [
            {
                "op": "and",
                "items": [
                    {
                        "op": "eq",
                        "field": "IsActive",
                        "value": true
                    },
                    {
                        "op": "eq",
                        "field": "referenceNumber",
                        "value": "' + $guid + '"
                    }
                ]
            }
        ]
    }'

    $Headers = @{
        "UserName"           = $API_USER_NAME
        "Secret"             = $API_SECRET
        "ApiIntegrationCode" = $API_INTEGRATION_CODE
    }

    $Result = Invoke-RestMethod -Method GET -Uri $Uri -Headers $Headers
    Debug-Print($Uri)


    return $Result.items
}

function Get-Company-Name-By-Id ($companyId) {
    $BaseUrl = Get-Zone-Information-Url
    $Uri = $BaseUrl + 'V1.0/Companies/' + $companyId

    $Headers = @{
        "UserName"           = $API_USER_NAME
        "Secret"             = $API_SECRET
        "ApiIntegrationCode" = $API_INTEGRATION_CODE
    }

    $Result = Invoke-RestMethod -Method GET -Uri $Uri -Headers $Headers

    return $Result.item.companyName
}
function Get-Location-Name-By-Id($locationId) {
    $BaseUrl = Get-Zone-Information-Url
    $Uri = $BaseUrl + 'V1.0/CompanyLocations/' + $locationId

    $Headers = @{
        "UserName"           = $API_USER_NAME
        "Secret"             = $API_SECRET
        "ApiIntegrationCode" = $API_INTEGRATION_CODE
    }

    $Result = Invoke-RestMethod -Method GET -Uri $Uri -Headers $Headers

    return $Result.item.name
}

$_zoneInformationUrl = $null
function Get-Zone-Information-Url {
    if ($null -eq $_zoneInformationUrl) {
        $Uri = "https://webservices2.autotask.net/ATServicesRest/V1.0/ZoneInformation?user=" + $API_USER_NAME

        $Result = Invoke-RestMethod -Method GET -Uri $Uri

        $_zoneInformationUrl = $Result.url
    }

    return $_zoneInformationUrl
}

function Get-Guid {
    $Results = Get-ItemProperty -Path HKLM:\SOFTWARE\CentraStage

    return $Results.DeviceID
}

$installationVariables = Get-Installation-Variables
try
{
    main
} catch {
    $ErrorMessage = $_.Exception.Message
    Write-Host "$(Get-TimeStamp) $ErrorMessage"
    exit 1
}