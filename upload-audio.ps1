$ErrorActionPreference = "Stop"

function Fail {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    Write-Host "ERROR: $Message" -ForegroundColor Red
    exit 1
}

function Read-DotEnv {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $values = @{}

    if (-not (Test-Path -LiteralPath $Path)) {
        Fail ".env file was not found. Copy .env.example to .env and edit it first."
    }

    Get-Content -LiteralPath $Path | ForEach-Object {
        $line = $_.Trim()

        if ($line.Length -eq 0 -or $line.StartsWith("#")) {
            return
        }

        $separatorIndex = $line.IndexOf("=")
        if ($separatorIndex -lt 1) {
            return
        }

        $name = $line.Substring(0, $separatorIndex).Trim()
        $value = $line.Substring($separatorIndex + 1).Trim()

        if (($value.StartsWith('"') -and $value.EndsWith('"')) -or ($value.StartsWith("'") -and $value.EndsWith("'"))) {
            $value = $value.Substring(1, $value.Length - 2)
        }

        $values[$name] = $value
    }

    return $values
}

function ConvertTo-PrettyJson {
    param(
        [Parameter(Mandatory = $true)]
        $Object
    )

    return ($Object | ConvertTo-Json -Depth 10)
}

$projectDir = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($projectDir)) {
    $projectDir = (Get-Location).Path
}

$envPath = Join-Path $projectDir ".env"
$envValues = Read-DotEnv -Path $envPath

$botToken = $envValues["MAX_BOT_TOKEN"]
$audioFilePath = $envValues["AUDIO_FILE_PATH"]

if ([string]::IsNullOrWhiteSpace($botToken) -or $botToken -eq "PUT_YOUR_MAX_BOT_TOKEN_HERE") {
    Fail "MAX_BOT_TOKEN is missing in .env."
}

if ([string]::IsNullOrWhiteSpace($audioFilePath)) {
    Fail "AUDIO_FILE_PATH is missing in .env."
}

if (-not (Test-Path -LiteralPath $audioFilePath -PathType Leaf)) {
    Fail "Audio file was not found: $audioFilePath"
}

$createUploadUrl = "https://platform-api.max.ru/uploads?type=audio"
$headers = @{
    Authorization = $botToken
}

Write-Host "Requesting upload URL..."
$uploadUrlResponse = Invoke-RestMethod -Method Post -Uri $createUploadUrl -Headers $headers

Write-Host ""
Write-Host "1. Upload URL response:"
Write-Host (ConvertTo-PrettyJson -Object $uploadUrlResponse)

$uploadUrl = $uploadUrlResponse.url
$mediaToken = $uploadUrlResponse.token

if ([string]::IsNullOrWhiteSpace($uploadUrl)) {
    Fail "Upload URL was not found in the first response."
}

Write-Host ""
Write-Host "Uploading audio file with curl.exe..."
$curlArgs = @(
    "-sS",
    "-X", "POST",
    "-F", "data=@$audioFilePath",
    $uploadUrl
)

$uploadRawResponseLines = & curl.exe @curlArgs
$curlExitCode = $LASTEXITCODE
$uploadRawResponse = $uploadRawResponseLines -join [Environment]::NewLine

Write-Host ""
Write-Host "2. Upload raw response:"
Write-Host $uploadRawResponse

if ($curlExitCode -ne 0) {
    Fail "curl.exe failed with exit code $curlExitCode."
}

$uploadSucceeded = $false
$uploadJson = $null
$trimmedUploadResponse = $uploadRawResponse.Trim()

if ($uploadRawResponse -match "<retval>\s*1\s*</retval>") {
    $uploadSucceeded = $true
}
elseif ($trimmedUploadResponse.StartsWith("{") -or $trimmedUploadResponse.StartsWith("[")) {
    $uploadJson = $null

    try {
        $uploadJson = $uploadRawResponse | ConvertFrom-Json
    }
    catch {
        $uploadJson = $null
    }

    if ($uploadJson -ne $null -and $uploadJson.retval -eq 1) {
        $uploadSucceeded = $true
    }

    if ($uploadJson -ne $null -and -not [string]::IsNullOrWhiteSpace($uploadJson.token)) {
        $uploadSucceeded = $true
    }
}

if (-not $uploadSucceeded) {
    Fail "Upload did not return a known success response."
}

if ([string]::IsNullOrWhiteSpace($mediaToken)) {
    if ($uploadJson -ne $null -and -not [string]::IsNullOrWhiteSpace($uploadJson.token)) {
        $mediaToken = $uploadJson.token
    }
}

if ([string]::IsNullOrWhiteSpace($mediaToken)) {
    Fail "Upload succeeded, but no media token was returned by the first response."
}

$attachment = [ordered]@{
    type = "audio"
    payload = [ordered]@{
        token = $mediaToken
    }
}

$messageBody = [ordered]@{
    text = $null
    attachments = @($attachment)
}

Write-Host ""
Write-Host "3. Media token:"
Write-Host $mediaToken

Write-Host ""
Write-Host "4. Ready audio attachment JSON:"
Write-Host (ConvertTo-PrettyJson -Object $attachment)

Write-Host ""
Write-Host "Example body for POST /messages:"
Write-Host (ConvertTo-PrettyJson -Object $messageBody)
