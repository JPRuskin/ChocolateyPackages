# Ensure prerequisites are available
if (-not (Get-Command dotnet -ErrorAction SilentlyContinue)) {
    choco install dotnet --confirm
}

try {
    Push-Location $PSScriptRoot
    dotnet build
} finally {
    Pop-Location
}
