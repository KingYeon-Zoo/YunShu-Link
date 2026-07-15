#Requires -Version 5.1
<#
.SYNOPSIS
    一键启动 YunShu-Link 的前后端开发环境。

.DESCRIPTION
    打开两个新的终端窗口：
      - 前端：manager-web（npm run serve，默认 http://localhost:8001）
      - 后端：xiaozhi-server 依赖的 Docker 服务（DB / Redis / Web）

    也可以单独启动某一侧：
      .\start-dev.ps1 -FrontendOnly
      .\start-dev.ps1 -BackendOnly
#>
[CmdletBinding()]
param(
    [switch]$FrontendOnly,
    [switch]$BackendOnly,
    [switch]$Help
)

if ($Help) {
    Get-Help -Name $PSCommandPath -Full
    exit
}

$ErrorActionPreference = 'Stop'

# 项目根目录（scripts 的上级目录）
$ProjectRoot = Split-Path -Parent $PSScriptRoot

function Start-FrontendWindow {
    $host.ui.RawUI.WindowTitle = 'YunShu-Link Frontend - manager-web'
    $frontendDir = Join-Path $ProjectRoot 'main' 'manager-web'

    Write-Host "[Frontend] 工作目录: $frontendDir" -ForegroundColor Cyan
    Set-Location $frontendDir

    Write-Host "[Frontend] 正在启动 Vue 开发服务器（http://localhost:8001）..." -ForegroundColor Cyan
    npm.cmd run serve
}

function Start-BackendWindow {
    $host.ui.RawUI.WindowTitle = 'YunShu-Link Backend - Docker'
    $backendDir = Join-Path $ProjectRoot 'main' 'xiaozhi-server'

    # 检查并启动 Docker Desktop
    Write-Host "[Backend] 检查 Docker Desktop 状态..." -ForegroundColor Green
    docker info *>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[Backend] Docker Desktop 未运行，正在启动..." -ForegroundColor Yellow
        $dockerDesktop = 'C:\Program Files\Docker\Docker\Docker Desktop.exe'
        if (Test-Path $dockerDesktop) {
            Start-Process -FilePath $dockerDesktop
        }
        else {
            Write-Error "找不到 Docker Desktop：$dockerDesktop，请手动启动 Docker 后再试。"
        }

        do {
            Start-Sleep -Seconds 5
            docker info *>$null
        } while ($LASTEXITCODE -ne 0)
        Write-Host "[Backend] Docker Desktop 已就绪。" -ForegroundColor Green
    }

    # 启动后端 Docker 服务
    Write-Host "[Backend] 正在启动 Docker 服务..." -ForegroundColor Green
    Set-Location $backendDir
    docker compose -f docker-compose_all.yml up xiaozhi-esp32-server-db xiaozhi-esp32-server-redis xiaozhi-esp32-server-web
}

# 单独模式：直接在当前终端执行对应逻辑
if ($FrontendOnly) {
    Start-FrontendWindow
    exit
}

if ($BackendOnly) {
    Start-BackendWindow
    exit
}

# 正常模式：打开两个新终端窗口
Write-Host "========================================" -ForegroundColor White
Write-Host "  YunShu-Link 开发环境启动器" -ForegroundColor White
Write-Host "========================================" -ForegroundColor White
Write-Host "项目根目录: $ProjectRoot" -ForegroundColor White
Write-Host "前端地址:   http://localhost:8001" -ForegroundColor White
Write-Host "后端地址:   http://localhost:8002/xiaozhi" -ForegroundColor White
Write-Host "`n正在打开两个新终端窗口..." -ForegroundColor White

$commonArgs = @('-NoExit', '-ExecutionPolicy', 'Bypass', '-File', $PSCommandPath)

Start-Process -FilePath powershell.exe `
    -ArgumentList ($commonArgs + '-FrontendOnly') `
    -WorkingDirectory $PSScriptRoot

Start-Process -FilePath powershell.exe `
    -ArgumentList ($commonArgs + '-BackendOnly') `
    -WorkingDirectory $PSScriptRoot

Write-Host "`n两个终端窗口已启动，开发服务器编译大约需要 30-60 秒。" -ForegroundColor White
Write-Host "可使用 scripts/check-dev.bat 验证服务是否就绪。" -ForegroundColor White
