param(
    [Parameter(Position = 0)]
    [string]$FilePath,

    [Parameter(Position = 1)]
    [Alias("Type")]
    [string]$UploadType,

    [switch]$NoPrompt,

    [switch]$JsonOnly
)

$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "max-upload-core.ps1")

$request = New-MaxUploadRequest `
    -FilePath $FilePath `
    -UploadType $UploadType `
    -NoPrompt:$NoPrompt `
    -ProjectDir $PSScriptRoot

if (-not $JsonOnly) {
    Write-Host "Local file: $($request.LocalFilePath)"
    Write-Host "Upload type: $($request.UploadType)"
    Write-Host "MIME type: $($request.MimeType)"
    Write-Host "Type source: $($request.TypeSource)"
    Write-Host ""
    Write-Host "Uploading file and preparing request body..."
    Write-Host "Please wait until the upload finishes. Large files and videos can take time."
}

$uploadUrlResponse = Request-MaxUploadUrl -Request $request
$uploadUrl = Get-MaxUploadUrl -UploadUrlResponse $uploadUrlResponse
$uploadFileResponse = Send-MaxUploadFile -Request $request -UploadUrl $uploadUrl

if (-not $JsonOnly) {
    Write-Host ""
    Write-Host "Upload server response:"
    if ([string]::IsNullOrWhiteSpace($uploadFileResponse.RawResponse)) {
        Write-Host "<empty>"
    }
    else {
        Write-Host $uploadFileResponse.RawResponse
    }
}

$upload = Complete-MaxUpload `
    -Request $request `
    -UploadUrlResponse $uploadUrlResponse `
    -UploadFileResponse $uploadFileResponse

$bodyJson = New-MaxRequestBodyJson -Upload $upload
$copiedToClipboard = $false

try {
    $bodyJson | Set-Clipboard
    $copiedToClipboard = $true
}
catch {
    $copiedToClipboard = $false
}

if (-not $JsonOnly) {
    Write-Host ""
    Write-Host "Request body JSON, one line:"
}

Write-Host $bodyJson

if (-not $JsonOnly) {
    if ($request.UploadType -eq "video") {
        Write-Host ""
        Write-Host "Video upload was accepted by MAX. If the request body does not work immediately, wait a bit and retry: video processing can take time." -ForegroundColor Yellow
    }

    if ($copiedToClipboard) {
        Write-Host ""
        Write-Host "Copied to clipboard."
    }
    else {
        Write-Host ""
        Write-Host "Could not copy to clipboard. Copy the JSON line manually." -ForegroundColor Yellow
    }
}
