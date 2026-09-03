# Environment check for Windows PowerShell + Docker Desktop.
# Run from the repo root:
#   powershell -ExecutionPolicy Bypass -File .\preflight.ps1
$ErrorActionPreference = "Continue"
$Fail = 0

function Write-Pass([string]$Message) {
    Write-Host "  PASS  $Message" -ForegroundColor Green
}
function Write-Fail([string]$Message) {
    Write-Host "  FAIL  $Message" -ForegroundColor Red
    $script:Fail = 1
}
function Write-Warn([string]$Message) {
    Write-Host "  WARN  $Message" -ForegroundColor Yellow
}

function Test-Cmd([string]$Name) {
    $null -ne (Get-Command $Name -ErrorAction SilentlyContinue)
}

function Wait-ForUrl([string]$Url, [int]$Attempts) {
    for ($i = 0; $i -lt $Attempts; $i++) {
        try {
            $response = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 5
            if ($response.StatusCode -eq 200) { return $true }
        } catch {
            # Not up yet.
        }
        Start-Sleep -Seconds 2
    }
    return $false
}

function Test-PortInUse([int]$Port) {
    $pattern = ":$Port\s+\S+\s+LISTENING"
    $matches = netstat -ano -p tcp 2>$null | Select-String -Pattern $pattern
    return $null -ne $matches
}

Write-Host ""
Write-Host "Starter -- preflight"
Write-Host "===================="
Write-Host ("  date      " + [DateTime]::UtcNow.ToString("yyyy-MM-ddTHH:mm:ssZ"))
Write-Host ("  host      Windows " + [System.Environment]::OSVersion.VersionString + " " + $env:PROCESSOR_ARCHITECTURE)
Write-Host ""

Write-Host "Tooling"
if (Test-Cmd "git") {
    $gitVersion = (git --version) -replace "^git version ", ""
    Write-Pass "git $gitVersion"
} else {
    Write-Fail "git not found"
}

if (Test-Cmd "docker") {
    $dockerVersion = ((docker --version) -split " ")[2].TrimEnd(",")
    Write-Pass "docker $dockerVersion"
    docker info *> $null
    if ($LASTEXITCODE -eq 0) {
        Write-Pass "docker daemon is running"
    } else {
        Write-Fail "docker is installed but the daemon is not running (start Docker Desktop)"
    }
    docker compose version *> $null
    if ($LASTEXITCODE -eq 0) {
        $composeVersion = (docker compose version --short 2>$null)
        Write-Pass "docker compose $composeVersion"
    } else {
        Write-Fail "'docker compose' (v2) not available"
    }
} else {
    Write-Fail "docker not found"
}

if ((Test-Cmd "curl.exe") -or (Test-Cmd "curl")) {
    Write-Pass "curl present"
} else {
    Write-Fail "curl not found"
}

if (Test-Cmd "make") {
    Write-Pass "make present (optional on Windows)"
} else {
    Write-Warn "make not found (optional -- use docker compose up --build -d)"
}

if (Test-Cmd "node") {
    Write-Pass "node $(node --version) (optional)"
} else {
    Write-Warn "node not found (optional -- Docker provides it)"
}

$pythonCmd = $null
foreach ($name in @("python3", "python")) {
    if (Test-Cmd $name) { $pythonCmd = $name; break }
}
if ($pythonCmd) {
    $pyVersion = (& $pythonCmd --version 2>$null)
    Write-Pass "$pyVersion (optional)"
} else {
    Write-Warn "python not found (optional -- Docker provides it)"
}

Write-Host ""
Write-Host "Resources"
try {
    $drive = (Get-Item -LiteralPath (Get-Location).Path).PSDrive
    $freeGb = [int][Math]::Floor($drive.Free / 1GB)
    if ($freeGb -ge 10) {
        Write-Pass "${freeGb}GB free disk"
    } else {
        Write-Fail "${freeGb}GB free disk (need 10GB)"
    }
} catch {
    Write-Warn "could not determine free disk space"
}

foreach ($port in 3000, 8000) {
    if (Test-PortInUse $port) {
        Write-Warn "port $port is already in use -- free it or change docker-compose.yml"
    } else {
        Write-Pass "port $port is free"
    }
}

Write-Host ""
Write-Host "Stack (build, start, check, stop -- this is the slow part)"
if ($Fail -ne 0) {
    Write-Warn "skipped -- fix the failures above first"
} elseif (-not (Test-Path -LiteralPath "docker-compose.yml")) {
    Write-Fail "docker-compose.yml not found -- run this script from the repo root"
} else {
    $log = Join-Path $env:TEMP "preflight-stack.log"
    docker compose up --build -d *> $log
    if ($LASTEXITCODE -ne 0) {
        Write-Fail "'docker compose up --build -d' failed -- see $log"
        Get-Content -LiteralPath $log -Tail 20
    } else {
        Write-Pass "images built and containers started"

        $apiOk = Wait-ForUrl "http://127.0.0.1:8000/api/health" 60
        if ($apiOk) {
            Write-Pass "API answered on http://127.0.0.1:8000/api/health"
        } else {
            Write-Fail "API did not answer within 120s"
        }

        $webOk = Wait-ForUrl "http://127.0.0.1:3000/" 30
        if ($webOk) {
            Write-Pass "frontend answered on http://127.0.0.1:3000"
        } else {
            Write-Fail "frontend did not answer within 60s"
        }

        if (-not ($apiOk -and $webOk)) {
            docker compose logs --no-color --tail 40 *>> $log
            Write-Host "  --- last 40 log lines (full log: $log) ---"
            Get-Content -LiteralPath $log -Tail 40
        }

        docker compose down *>> $log
        if ($LASTEXITCODE -eq 0) {
            Write-Pass "stack stopped (database volume kept)"
        } else {
            Write-Fail "'docker compose down' failed -- see $log"
        }
    }
}

Write-Host ""
Write-Host "Screen sharing (Zoom or Chrome Remote Desktop -- either one is enough)"
$zoomFound = $false
foreach ($base in @($env:APPDATA, $env:LOCALAPPDATA, $env:ProgramFiles, ${env:ProgramFiles(x86)})) {
    if (-not $base) { continue }
    if (Test-Path -LiteralPath (Join-Path $base "Zoom\bin\Zoom.exe")) { $zoomFound = $true }
}
$crdFound = $false
foreach ($base in @($env:ProgramFiles, ${env:ProgramFiles(x86)})) {
    if (-not $base) { continue }
    if (Test-Path -LiteralPath (Join-Path $base "Google\Chrome Remote Desktop")) { $crdFound = $true }
}
if (Get-Service -Name "chromoting" -ErrorAction SilentlyContinue) { $crdFound = $true }

if ($zoomFound) { Write-Pass "Zoom found" }
if ($crdFound) { Write-Pass "Chrome Remote Desktop found" }
if (-not ($zoomFound -or $crdFound)) {
    Write-Fail "neither Zoom nor Chrome Remote Desktop found -- install one of them"
    Write-Warn "if you do have one installed somewhere unusual, tell us and ignore this"
}

Write-Host ""
Write-Host "Editor"
Write-Warn "Not checkable from here. Confirm your editor and any AI assistant"
Write-Warn "are installed, signed in, and can edit this repo."

Write-Host ""
if ($Fail -eq 0) {
    Write-Host "RESULT: READY -- paste this whole output back to us."
    exit 0
}
Write-Host "RESULT: NOT READY -- send us this output and we will help."
exit 1
