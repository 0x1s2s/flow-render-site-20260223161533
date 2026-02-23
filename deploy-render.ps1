param(
  [Parameter(Mandatory = $true)]
  [string]$RenderApiKey,

  [Parameter(Mandatory = $false)]
  [string]$ServiceName = ("flow-site-" + (Get-Date -Format "yyyyMMddHHmmss")),

  [Parameter(Mandatory = $false)]
  [string]$RepoUrl = "https://github.com/0x1s2s/flow-render-site-20260223161533",

  [Parameter(Mandatory = $false)]
  [string]$Branch = "main"
)

$ErrorActionPreference = "Stop"

function Invoke-Render {
  param(
    [Parameter(Mandatory = $true)][string]$Method,
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $false)][string]$Body
  )

  $url = "https://api.render.com$Path"
  $headers = @(
    "-H", "Authorization: Bearer $RenderApiKey",
    "-H", "Content-Type: application/json"
  )

  if ($Body) {
    $tmp = [System.IO.Path]::GetTempFileName()
    Set-Content -Path $tmp -Encoding ascii -Value $Body
    try {
      return curl.exe -s -X $Method $url @headers --data-binary "@$tmp"
    } finally {
      Remove-Item -Force $tmp -ErrorAction SilentlyContinue
    }
  }

  return curl.exe -s -X $Method $url @headers
}

$ownersRaw = Invoke-Render -Method GET -Path "/v1/owners"
$owners = $ownersRaw | ConvertFrom-Json
if (-not $owners -or -not $owners[0].owner.id) {
  throw "No Render owner found for this API key."
}

$ownerId = $owners[0].owner.id
$payload = [ordered]@{
  type           = "static_site"
  name           = $ServiceName
  ownerId        = $ownerId
  repo           = $RepoUrl
  branch         = $Branch
  autoDeploy     = "yes"
  serviceDetails = [ordered]@{
    buildCommand = ""
    publishPath  = "."
  }
} | ConvertTo-Json -Compress

$createRaw = Invoke-Render -Method POST -Path "/v1/services" -Body $payload
$create = $createRaw | ConvertFrom-Json
if ($create.message) {
  Write-Output "Render API error: $($create.message)"
  exit 1
}

Write-Output ("Service ID: " + $create.id)
Write-Output ("Dashboard URL: " + $create.dashboardUrl)
if ($create.serviceDetails.url) {
  Write-Output ("Live URL: " + $create.serviceDetails.url)
}
