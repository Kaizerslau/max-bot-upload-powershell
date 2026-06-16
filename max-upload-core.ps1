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

function ConvertTo-CompactJson {
    param(
        [Parameter(Mandatory = $true)]
        $Object
    )

    return ($Object | ConvertTo-Json -Depth 10 -Compress)
}

function Normalize-InputPath {
    param(
        [string]$Path
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return ""
    }

    $cleanPath = $Path.Trim()

    if ($cleanPath.StartsWith("& ")) {
        $cleanPath = $cleanPath.Substring(2).Trim()
    }

    if (($cleanPath.StartsWith('"') -and $cleanPath.EndsWith('"')) -or ($cleanPath.StartsWith("'") -and $cleanPath.EndsWith("'"))) {
        $cleanPath = $cleanPath.Substring(1, $cleanPath.Length - 2)
    }

    return [Environment]::ExpandEnvironmentVariables($cleanPath)
}

function Resolve-LocalFilePath {
    param(
        [string]$Path
    )

    $cleanPath = Normalize-InputPath -Path $Path

    if ([string]::IsNullOrWhiteSpace($cleanPath)) {
        Fail "File path is missing."
    }

    try {
        $resolvedPath = Resolve-Path -LiteralPath $cleanPath
    }
    catch {
        Fail "File was not found: $cleanPath"
    }

    if ($resolvedPath.Count -gt 1) {
        Fail "File path points to more than one item: $cleanPath"
    }

    $providerPath = $resolvedPath.ProviderPath

    if (-not (Test-Path -LiteralPath $providerPath -PathType Leaf)) {
        Fail "Path is not a file: $providerPath"
    }

    return $providerPath
}

function Normalize-UploadType {
    param(
        [string]$Type
    )

    if ([string]::IsNullOrWhiteSpace($Type)) {
        return "auto"
    }

    $normalizedType = $Type.Trim().ToLowerInvariant()

    if ($normalizedType -eq "photo") {
        Fail "Upload type 'photo' is no longer supported by MAX. Use 'image' instead."
    }

    $allowedTypes = @("auto", "image", "video", "audio", "file")
    if ($allowedTypes -notcontains $normalizedType) {
        Fail "Unsupported upload type '$Type'. Use one of: auto, image, video, audio, file."
    }

    return $normalizedType
}

function Resolve-UploadType {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$RequestedType
    )

    if ($RequestedType -ne "auto") {
        return $RequestedType
    }

    $extension = [System.IO.Path]::GetExtension($Path).ToLowerInvariant()

    $imageExtensions = @(".jpg", ".jpeg", ".png", ".gif", ".tiff", ".tif", ".bmp", ".heic")
    $videoExtensions = @(".mp4", ".mov", ".mkv", ".webm", ".matroska")
    $audioExtensions = @(".mp3", ".wav", ".m4a", ".aac", ".ogg", ".opus", ".flac")

    if ($imageExtensions -contains $extension) {
        return "image"
    }

    if ($videoExtensions -contains $extension) {
        return "video"
    }

    if ($audioExtensions -contains $extension) {
        return "audio"
    }

    return "file"
}

function Get-MimeType {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$UploadType
    )

    $extension = [System.IO.Path]::GetExtension($Path).ToLowerInvariant()
    $mimeTypes = @{
        ".jpg" = "image/jpeg"
        ".jpeg" = "image/jpeg"
        ".png" = "image/png"
        ".gif" = "image/gif"
        ".tiff" = "image/tiff"
        ".tif" = "image/tiff"
        ".bmp" = "image/bmp"
        ".heic" = "image/heic"
        ".mp4" = "video/mp4"
        ".mov" = "video/quicktime"
        ".mkv" = "video/x-matroska"
        ".matroska" = "video/x-matroska"
        ".webm" = "video/webm"
        ".mp3" = "audio/mpeg"
        ".wav" = "audio/wav"
        ".m4a" = "audio/mp4"
        ".aac" = "audio/aac"
        ".ogg" = "audio/ogg"
        ".opus" = "audio/ogg"
        ".flac" = "audio/flac"
        ".txt" = "text/plain"
        ".json" = "application/json"
        ".pdf" = "application/pdf"
        ".doc" = "application/msword"
        ".docx" = "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        ".xls" = "application/vnd.ms-excel"
        ".xlsx" = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
    }

    if ($mimeTypes.ContainsKey($extension)) {
        return $mimeTypes[$extension]
    }

    if ($UploadType -eq "image") {
        return "image/*"
    }

    if ($UploadType -eq "video") {
        return "video/*"
    }

    if ($UploadType -eq "audio") {
        return "audio/*"
    }

    return "application/octet-stream"
}

function Try-ConvertFromJson {
    param(
        [string]$RawResponse
    )

    if ([string]::IsNullOrWhiteSpace($RawResponse)) {
        return $null
    }

    $trimmedResponse = $RawResponse.Trim()
    if (-not ($trimmedResponse.StartsWith("{") -or $trimmedResponse.StartsWith("["))) {
        return $null
    }

    try {
        return ($RawResponse | ConvertFrom-Json)
    }
    catch {
        return $null
    }
}

function Test-JsonProperty {
    param(
        $Object,

        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    if ($Object -eq $null) {
        return $false
    }

    if ($Object -is [System.Collections.IDictionary]) {
        return $Object.Contains($Name)
    }

    return ($Object.PSObject.Properties.Name -contains $Name)
}

function Get-ObjectPropertyValue {
    param(
        $Object,

        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    if ($Object -is [System.Collections.IDictionary] -and $Object.Contains($Name)) {
        return $Object[$Name]
    }

    if (Test-JsonProperty -Object $Object -Name $Name) {
        return $Object.$Name
    }

    return $null
}

function Get-TokenFromUrl {
    param(
        [string]$Url
    )

    if ([string]::IsNullOrWhiteSpace($Url)) {
        return $null
    }

    try {
        $uri = [Uri]$Url
    }
    catch {
        return $null
    }

    if ([string]::IsNullOrWhiteSpace($uri.Query)) {
        return $null
    }

    $query = $uri.Query.TrimStart("?")
    $parts = $query -split "&"

    foreach ($part in $parts) {
        if ([string]::IsNullOrWhiteSpace($part)) {
            continue
        }

        $pair = $part -split "=", 2
        if ($pair.Count -ne 2) {
            continue
        }

        $name = [Uri]::UnescapeDataString($pair[0])
        $value = [Uri]::UnescapeDataString($pair[1])

        if ($name -eq "token" -and -not [string]::IsNullOrWhiteSpace($value)) {
            return $value
        }
    }

    return $null
}

function Read-UploadResult {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RawResponse
    )

    $json = Try-ConvertFromJson -RawResponse $RawResponse
    $token = Get-ObjectPropertyValue -Object $json -Name "token"
    $retval = Get-ObjectPropertyValue -Object $json -Name "retval"
    $fileId = Get-ObjectPropertyValue -Object $json -Name "fileId"
    $photos = Get-ObjectPropertyValue -Object $json -Name "photos"
    $hasXmlRetvalSuccess = ($RawResponse -match "<retval>\s*1\s*</retval>")
    $hasJsonRetvalSuccess = ($json -ne $null -and $retval -eq 1)
    $hasToken = -not [string]::IsNullOrWhiteSpace($token)
    $hasFilePayload = -not [string]::IsNullOrWhiteSpace($fileId)
    $hasImagePayload = ($photos -ne $null)

    return [pscustomobject][ordered]@{
        Json = $json
        Token = $token
        Succeeded = ($hasXmlRetvalSuccess -or $hasJsonRetvalSuccess -or $hasToken -or $hasFilePayload -or $hasImagePayload)
    }
}

function Get-FirstImageToken {
    param(
        $Payload
    )

    $photos = Get-ObjectPropertyValue -Object $Payload -Name "photos"
    if ($photos -eq $null) {
        return $null
    }

    foreach ($photo in $photos.PSObject.Properties) {
        $token = Get-ObjectPropertyValue -Object $photo.Value -Name "token"
        if (-not [string]::IsNullOrWhiteSpace($token)) {
            return $token
        }
    }

    return $null
}

function Get-MaxAttachmentToken {
    param(
        $Payload,
        $UploadResult,
        [string]$TokenFromUploadUrlResponse,
        [string]$TokenFromUploadUrl
    )

    $payloadToken = Get-ObjectPropertyValue -Object $Payload -Name "token"
    if (-not [string]::IsNullOrWhiteSpace($payloadToken)) {
        return $payloadToken
    }

    $imageToken = Get-FirstImageToken -Payload $Payload
    if (-not [string]::IsNullOrWhiteSpace($imageToken)) {
        return $imageToken
    }

    if ($UploadResult -ne $null -and -not [string]::IsNullOrWhiteSpace($UploadResult.Token)) {
        return $UploadResult.Token
    }

    if (-not [string]::IsNullOrWhiteSpace($TokenFromUploadUrlResponse)) {
        return $TokenFromUploadUrlResponse
    }

    if (-not [string]::IsNullOrWhiteSpace($TokenFromUploadUrl)) {
        return $TokenFromUploadUrl
    }

    return $null
}

function Resolve-ProjectDir {
    param(
        [string]$ProjectDir
    )

    if (-not [string]::IsNullOrWhiteSpace($ProjectDir)) {
        return $ProjectDir
    }

    if (-not [string]::IsNullOrWhiteSpace($PSScriptRoot)) {
        return $PSScriptRoot
    }

    return (Get-Location).Path
}

function New-MaxUploadRequest {
    param(
        [string]$FilePath,
        [string]$UploadType,
        [switch]$NoPrompt,
        [string]$ProjectDir
    )

    $resolvedProjectDir = Resolve-ProjectDir -ProjectDir $ProjectDir
    $envPath = Join-Path $resolvedProjectDir ".env"
    $envValues = Read-DotEnv -Path $envPath

    $botToken = $envValues["MAX_BOT_TOKEN"]
    if ([string]::IsNullOrWhiteSpace($botToken) -or $botToken -eq "PUT_YOUR_MAX_BOT_TOKEN_HERE") {
        Fail "MAX_BOT_TOKEN is missing in .env."
    }

    $configuredFilePath = $envValues["MAX_FILE_PATH"]
    $legacyAudioFilePath = $envValues["AUDIO_FILE_PATH"]

    if ([string]::IsNullOrWhiteSpace($FilePath)) {
        if (-not [string]::IsNullOrWhiteSpace($configuredFilePath)) {
            $FilePath = $configuredFilePath
        }
        elseif (-not [string]::IsNullOrWhiteSpace($legacyAudioFilePath)) {
            Write-Host "Using legacy AUDIO_FILE_PATH from .env. Prefer passing the file path at launch or using MAX_FILE_PATH."
            $FilePath = $legacyAudioFilePath
        }
    }

    if ([string]::IsNullOrWhiteSpace($FilePath)) {
        if ($NoPrompt) {
            Fail "File path is missing. Pass it as the first argument or set MAX_FILE_PATH in .env."
        }

        Write-Host "Enter a local file path. You can drag-and-drop a file into this window and press Enter."
        $FilePath = Read-Host "File path"
    }

    $localFilePath = Resolve-LocalFilePath -Path $FilePath

    if ([string]::IsNullOrWhiteSpace($UploadType)) {
        $UploadType = $envValues["MAX_UPLOAD_TYPE"]
    }

    $requestedUploadType = Normalize-UploadType -Type $UploadType
    $resolvedUploadType = Resolve-UploadType -Path $localFilePath -RequestedType $requestedUploadType
    $mimeType = Get-MimeType -Path $localFilePath -UploadType $resolvedUploadType
    $typeSource = "explicit"

    if ($requestedUploadType -eq "auto") {
        $typeSource = "auto by file extension"
    }

    return [pscustomobject][ordered]@{
        ProjectDir = $resolvedProjectDir
        BotToken = $botToken
        LocalFilePath = $localFilePath
        RequestedUploadType = $requestedUploadType
        UploadType = $resolvedUploadType
        MimeType = $mimeType
        TypeSource = $typeSource
        CreateUploadUrl = "https://platform-api.max.ru/uploads?type=$resolvedUploadType"
    }
}

function Request-MaxUploadUrl {
    param(
        [Parameter(Mandatory = $true)]
        $Request
    )

    $headers = @{
        Authorization = $Request.BotToken
    }

    return (Invoke-RestMethod -Method Post -Uri $Request.CreateUploadUrl -Headers $headers)
}

function Get-MaxUploadUrl {
    param(
        [Parameter(Mandatory = $true)]
        $UploadUrlResponse
    )

    $uploadUrl = $UploadUrlResponse.url

    if ([string]::IsNullOrWhiteSpace($uploadUrl)) {
        Fail "Upload URL was not found in the first response."
    }

    return $uploadUrl
}

function Send-MaxUploadFile {
    param(
        [Parameter(Mandatory = $true)]
        $Request,

        [Parameter(Mandatory = $true)]
        [string]$UploadUrl
    )

    $curlArgs = @(
        "-sS",
        "-X", "POST",
        "-F", "data=@$($Request.LocalFilePath);type=$($Request.MimeType)",
        $UploadUrl
    )

    $uploadRawResponseLines = & curl.exe @curlArgs
    $curlExitCode = $LASTEXITCODE
    $uploadRawResponse = $uploadRawResponseLines -join [Environment]::NewLine

    return [pscustomobject][ordered]@{
        RawResponse = $uploadRawResponse
        CurlExitCode = $curlExitCode
    }
}

function Complete-MaxUpload {
    param(
        [Parameter(Mandatory = $true)]
        $Request,

        [Parameter(Mandatory = $true)]
        $UploadUrlResponse,

        [Parameter(Mandatory = $true)]
        $UploadFileResponse
    )

    if ($UploadFileResponse.CurlExitCode -ne 0) {
        Fail "curl.exe failed with exit code $($UploadFileResponse.CurlExitCode)."
    }

    $uploadResult = Read-UploadResult -RawResponse $UploadFileResponse.RawResponse

    if (-not $uploadResult.Succeeded) {
        Fail "Upload did not return a known success response."
    }

    $uploadUrl = Get-MaxUploadUrl -UploadUrlResponse $UploadUrlResponse
    $tokenFromUploadUrlResponse = $UploadUrlResponse.token
    $tokenFromUploadUrl = Get-TokenFromUrl -Url $uploadUrl
    $payload = $null

    if ($Request.UploadType -eq "audio" -or $Request.UploadType -eq "video") {
        $mediaToken = $tokenFromUploadUrlResponse

        if ([string]::IsNullOrWhiteSpace($mediaToken)) {
            $mediaToken = $uploadResult.Token
        }

        if ([string]::IsNullOrWhiteSpace($mediaToken)) {
            Fail "Upload succeeded, but no media token was returned for $($Request.UploadType)."
        }

        $payload = [ordered]@{
            token = $mediaToken
        }
    }
    else {
        if ($uploadResult.Json -ne $null) {
            $payload = $uploadResult.Json
        }
        elseif (-not [string]::IsNullOrWhiteSpace($uploadResult.Token)) {
            $payload = [ordered]@{
                token = $uploadResult.Token
            }
        }
        elseif (-not [string]::IsNullOrWhiteSpace($tokenFromUploadUrl)) {
            $payload = [ordered]@{
                token = $tokenFromUploadUrl
            }
        }

        if ($payload -eq $null) {
            Fail "Upload succeeded, but no JSON payload or token was returned for $($Request.UploadType)."
        }
    }

    $attachment = [ordered]@{
        type = $Request.UploadType
        payload = $payload
    }

    $messageBody = [ordered]@{
        text = $null
        attachments = @($attachment)
    }

    $attachmentToken = Get-MaxAttachmentToken `
        -Payload $payload `
        -UploadResult $uploadResult `
        -TokenFromUploadUrlResponse $tokenFromUploadUrlResponse `
        -TokenFromUploadUrl $tokenFromUploadUrl

    return [pscustomobject][ordered]@{
        Request = $Request
        UploadUrlResponse = $UploadUrlResponse
        UploadUrl = $uploadUrl
        UploadRawResponse = $UploadFileResponse.RawResponse
        UploadResult = $uploadResult
        Payload = $payload
        Attachment = $attachment
        MessageBody = $messageBody
        AttachmentToken = $attachmentToken
    }
}

function New-MaxRequestBodyJson {
    param(
        [Parameter(Mandatory = $true)]
        $Upload
    )

    if ([string]::IsNullOrWhiteSpace($Upload.AttachmentToken)) {
        Fail "Upload succeeded, but no token was found for request body JSON."
    }

    $requestBody = [ordered]@{
        text = ""
        attachments = @(
            [ordered]@{
                type = $Upload.Request.UploadType
                payload = [ordered]@{
                    token = $Upload.AttachmentToken
                }
            }
        )
        format = "html"
    }

    return (ConvertTo-CompactJson -Object $requestBody)
}
