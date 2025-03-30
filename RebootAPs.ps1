function Get-Timestamp
{
    return "[" + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss') + "]"
}

# Load configuration file from REBOOT_CONFIG_PATH or default to config.json
$configPath = $env:REBOOT_CONFIG_PATH
if (-not $configPath) { $configPath = "config.json" }
if (-not (Test-Path $configPath))
{
    Write-Host "$(Get-Timestamp) [DEBUG] Configuration file not found at $configPath. Exiting."
    exit 1
}
try
{
    $configContent = Get-Content $configPath -Raw | ConvertFrom-Json
}
catch
{
    Write-Host "$(Get-Timestamp) [DEBUG] Failed to parse configuration file. Exiting."
    exit 1
}

# Get Unifi controller connection details from environment variables
$controllerUrl = $env:UNIFI_CONTROLLER_URL      # e.g. "https://unifi.example.com"
$controllerUser = $env:UNIFI_CONTROLLER_USER        # e.g. "YourUsername"
$controllerPassword = $env:UNIFI_CONTROLLER_PASSWORD  # e.g. "YourPassword"
if (-not ($controllerUrl -and $controllerUser -and $controllerPassword))
{
    Write-Host "$(Get-Timestamp) [DEBUG] Missing one or more Unifi controller environment variables. Exiting."
    exit 1
}

# Define a cookie file for cURL session persistence
$cookieFile = "cookie.txt"

# Function to log in to the Unifi controller via cURL.
# Sensitive information is not printed in logs.
function Login-Unifi
{
    param(
        [string]$url,
        [string]$user,
        [string]$pass,
        [string]$cookieFile
    )
    $loginUrl = "$url/api/login"
    $loginBody = @{ username = $user; password = $pass } | ConvertTo-Json -Compress
    $args = @(
        "-k", # Ignore SSL certificate errors
        "-c", $cookieFile, # Save cookies to file
        "-X", "POST",
        "-H", "Content-Type: application/json",
        "-d", $loginBody,
        $loginUrl
    )
    # Do not log sensitive details; print a masked command instead.
    Write-Host "$(Get-Timestamp) [DEBUG] Logging in with curl: curl -k -c `"$cookieFile`" -X POST -H `"Content-Type: application/json`" -d [REDACTED] `"$loginUrl`""
    try
    {
        $loginResult = & curl @args
        Write-Host "$(Get-Timestamp) [DEBUG] Login response: $loginResult"
    }
    catch
    {
        Write-Host "$(Get-Timestamp) [DEBUG] Error during login: $($_.Exception.Message)"
        exit 1
    }
}

# Function to reboot an AP using cURL and the session cookie.
# If the response indicates that login is required, re-authenticate and retry.
function Reboot-AP
{
    param(
        [string]$mac,
        [pscustomobject]$apDetails
    )
    Write-Host "$(Get-Timestamp) [DEBUG] Initiating reboot for AP: $($apDetails.name) (MAC: $mac)"
    $uri = "$controllerUrl/api/s/default/cmd/devmgr"
    $jsonBody = @{ cmd = "restart"; mac = $mac } | ConvertTo-Json -Compress
    $args = @(
        "-k", # Ignore SSL certificate errors
        "-b", $cookieFile, # Use cookie file for authentication
        "-X", "POST",
        "-H", "Content-Type: application/json",
        "-d", $jsonBody,
        $uri
    )
    Write-Host "$(Get-Timestamp) [DEBUG] Sending curl command: curl $($args -join ' ')"
    try
    {
        $result = & curl @args
    }
    catch
    {
        Write-Host "$(Get-Timestamp) [DEBUG] Error during curl call for AP ${mac}: $($_.Exception.Message)"
        return
    }
    if ($result -match "LoginRequired" -or $result -match "api.err.LoginRequired")
    {
        Write-Host "$(Get-Timestamp) [DEBUG] Session expired. Re-authenticating..."
        Login-Unifi -url $controllerUrl -user $controllerUser -pass $controllerPassword -cookieFile $cookieFile
        # Retry the reboot call once after re-login.
        $result = & curl @args
    }
    Write-Host "$(Get-Timestamp) [DEBUG] Reboot response for AP ${mac}: $result"
}

# At startup, log in to the controller
Login-Unifi -url $controllerUrl -user $controllerUser -pass $controllerPassword -cookieFile $cookieFile

# Main loop: Check schedule and reboot matching APs
while ($true)
{
    $now = Get-Date
    $currentDay = $now.DayOfWeek.ToString().ToLower()
    $currentTime = $now.ToString("HH:mm")
    Write-Host "$(Get-Timestamp) [DEBUG] Checking schedules - Day: $currentDay, Time: $currentTime"
    
    foreach ($prop in $configContent.PSObject.Properties)
    {
        $mac = $prop.Name
        $apDetails = $prop.Value
        Write-Host "$(Get-Timestamp) [DEBUG] Config for AP ${mac}: " + ($apDetails | ConvertTo-Json -Depth 3)
        if (($apDetails.days -contains $currentDay) -and ($currentTime -eq $apDetails.time))
        {
            Write-Host "$(Get-Timestamp) [DEBUG] Schedule match found for AP ${mac} ($($apDetails.name)). Reboot time: $($apDetails.time)"
            Reboot-AP -mac $mac -apDetails $apDetails
        }
        else
        {
            Write-Host "$(Get-Timestamp) [DEBUG] No schedule match for AP ${mac} ($($apDetails.name)). Expected time: $($apDetails.time) on days: " + ($apDetails.days -join ", ")
        }
    }
    Start-Sleep -Seconds 60
}
