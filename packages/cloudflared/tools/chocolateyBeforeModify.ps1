$ErrorActionPreference = 'Stop'

# Stop the cloudflared service if it is running
$serviceName = 'cloudflared'
$service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
if ($service) {
    if ($service.Status -eq 'Running') {
        Write-Output "Stopping service '$serviceName'"
        Stop-Service -Name $serviceName
    }
}