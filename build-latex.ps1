$ErrorActionPreference = "Stop"

$projectRoot = $PSScriptRoot
$sourceDirectory = Join-Path $projectRoot "src"
$dockerDirectory = Join-Path $projectRoot "docker"
$buildDirectory = Join-Path $projectRoot "build"
$image = "praktikumsbericht-latex:local"

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    throw "Docker was not found. Install Docker Desktop, start it, and restart VS Code."
}

docker info *> $null
if ($LASTEXITCODE -ne 0) {
    throw "Docker Desktop is installed but its engine is not running. Start Docker Desktop and try again."
}

docker image inspect $image *> $null
if ($LASTEXITCODE -ne 0) {
    Write-Host "Building the local LaTeX image. The first build can take several minutes."
    & docker build --pull --tag $image $dockerDirectory
    if ($LASTEXITCODE -ne 0) {
        throw "Building the LaTeX image failed with exit code $LASTEXITCODE."
    }
}

New-Item -ItemType Directory -Force -Path $buildDirectory | Out-Null

$fontCacheDirectory = Join-Path $buildDirectory ".texmfvar"
New-Item -ItemType Directory -Force -Path $fontCacheDirectory | Out-Null

$hostFontDirectory = Join-Path $env:SystemRoot "Fonts"

$dockerArguments = @(
    "run"
    "--rm"
    "--network", "none"
    "--read-only"
    "--security-opt", "no-new-privileges"
    "--cap-drop", "ALL"
    "--pids-limit", "512"
    "--memory", "2g"
    "--cpus", "2"
    "--tmpfs", "/tmp:rw,noexec,nosuid,size=512m"
    "--env", "HOME=/tmp"
    "--env", "OSFONTDIR=/hostfonts"
    "--env", "TEXMFVAR=/output/.texmfvar"
    "--mount", "type=bind,source=$sourceDirectory,target=/work,readonly"
    "--mount", "type=bind,source=$hostFontDirectory,target=/hostfonts,readonly"
    "--mount", "type=bind,source=$buildDirectory,target=/output"
    "--workdir", "/work"
    $image
    "latexmk"
    "-lualatex"
    "-g"
    "-outdir=/output"
    "-interaction=nonstopmode"
    "-halt-on-error"
    "main.tex"
)

& docker @dockerArguments
if ($LASTEXITCODE -ne 0) {
    throw "LaTeX compilation failed with exit code $LASTEXITCODE. See build/main.log for details."
}

Write-Host "Created $buildDirectory\main.pdf"