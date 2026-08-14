# 打包 Magisk/KSU 模块为 zip，输出到仓库根目录
# 用法: pwsh -NoProfile -ExecutionPolicy Bypass -File .vscode/build-module.ps1
$ErrorActionPreference = 'Stop'

$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Set-Location $root

# 1. 从 module.prop 读取模块 id 与版本，组成 zip 名（如 enable-wifi-7-v11.zip）
$prop = Get-Content -Path (Join-Path $root 'module.prop')
$id   = (($prop | Where-Object { $_ -like 'id=*' })    -split '=', 2)[1].Trim()
$ver  = (($prop | Where-Object { $_ -like 'version=*' }) -split '=', 2)[1].Trim()
if (-not $id) { throw 'module.prop 缺少 id 字段' }
if (-not $ver) { $ver = Get-Date -Format 'yyyyMMdd' }

$zipName = "$id-$ver.zip"
$zipPath = Join-Path $root $zipName
Write-Host "[build] 模块: $id  版本: $ver" -ForegroundColor Cyan
Write-Host "[build] 输出: $zipPath" -ForegroundColor Cyan

# 2. 建 staging 临时目录，只复制模块需要的文件（排除 .git / zip / 临时文件等）
$staging = Join-Path ([System.IO.Path]::GetTempPath()) ("mod-pkg-{0}" -f [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $staging -Force | Out-Null

try {
    $includeItems = Get-ChildItem -Path $root -Force | Where-Object {
        $_.Name -notin @('.git', '.gitattributes', '.gitignore', '.vscode') -and
        $_.Name -ne '.tmp_boot_check.sh' -and
        $_.Name -notlike '*.zip'
    }
    foreach ($item in $includeItems) {
        Copy-Item -Path $item.FullName -Destination $staging -Recurse -Force
    }

    # 3. 压缩为 zip：先写临时文件，再原子替换目标（带重试，避免文件被占用报错）
    Add-Type -AssemblyName System.IO.Compression.FileSystem

    $tmpZip = Join-Path ([System.IO.Path]::GetTempPath()) ("{0}-{1}.tmp" -f $id, [guid]::NewGuid().ToString('N'))
    [System.IO.Compression.ZipFile]::CreateFromDirectory(
        $staging, $tmpZip,
        [System.IO.Compression.CompressionLevel]::Optimal, $false)

    # 目标文件可能被资源管理器预览、杀毒扫描或编辑器等占用，重试最多 20 次（共约 10 秒）
    $moved = $false
    for ($i = 1; $i -le 20; $i++) {
        try {
            Move-Item -Path $tmpZip -Destination $zipPath -Force -ErrorAction Stop
            $moved = $true
            break
        } catch {
            if ($i -eq 1 -or $i % 5 -eq 0) {
                Write-Host "[build] 目标文件被占用，等待释放... ($i/20)" -ForegroundColor Yellow
            }
            Start-Sleep -Milliseconds 500
        }
    }
    if (-not $moved) {
        throw "无法替换 $zipName（文件被其他进程占用）。请先关闭打开它的程序：VS Code 中的 zip 标签页、资源管理器预览窗格、7-Zip/WinRAR/Bandizip 等；若在 PowerShell 里 OpenRead 过该 zip，先执行 [GC]::Collect()。临时包保留在: $tmpZip"
    }

    $sizeKB = [math]::Round((Get-Item $zipPath).Length / 1KB, 1)
    Write-Host "[build] 完成: $zipName ($sizeKB KB)" -ForegroundColor Green
}
finally {
    if (Test-Path $staging) { Remove-Item $staging -Recurse -Force }
}
