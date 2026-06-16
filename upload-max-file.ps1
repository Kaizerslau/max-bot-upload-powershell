param(
    [Parameter(Position = 0)]
    [string]$FilePath,

    [Parameter(Position = 1)]
    [Alias("Type")]
    [string]$UploadType,

    [switch]$NoPrompt
)

$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "max-upload-core.ps1")

$request = New-MaxUploadRequest `
    -FilePath $FilePath `
    -UploadType $UploadType `
    -NoPrompt:$NoPrompt `
    -ProjectDir $PSScriptRoot

Write-Host "Local file: $($request.LocalFilePath)"
Write-Host "Upload type: $($request.UploadType)"
Write-Host "MIME type: $($request.MimeType)"
Write-Host "Type source: $($request.TypeSource)"

Write-Host ""
Write-Host "Requesting upload URL..."
$uploadUrlResponse = Request-MaxUploadUrl -Request $request

Write-Host ""
Write-Host "1. Upload URL response:"
Write-Host (ConvertTo-PrettyJson -Object $uploadUrlResponse)

$uploadUrl = Get-MaxUploadUrl -UploadUrlResponse $uploadUrlResponse

Write-Host ""
Write-Host "Uploading file with curl.exe..."
Write-Host "Please wait until the upload finishes. Large files and videos can take time."
$uploadFileResponse = Send-MaxUploadFile -Request $request -UploadUrl $uploadUrl

Write-Host ""
Write-Host "2. Upload raw response:"
Write-Host $uploadFileResponse.RawResponse

$upload = Complete-MaxUpload `
    -Request $request `
    -UploadUrlResponse $uploadUrlResponse `
    -UploadFileResponse $uploadFileResponse

Write-Host ""
Write-Host "3. Attachment payload:"
Write-Host (ConvertTo-PrettyJson -Object $upload.Payload)

Write-Host ""
Write-Host "4. Ready attachment JSON:"
Write-Host (ConvertTo-PrettyJson -Object $upload.Attachment)

Write-Host ""
Write-Host "Example body for POST /messages:"
Write-Host (ConvertTo-PrettyJson -Object $upload.MessageBody)
