# =============================================================
# 【配置区：每个人自己修改这里】
$archivePath  = "C:\Users\姜成龍（JIANGChenglong）\Desktop\AMISDB"
$networkPath  = "\\192.168.1.83\Proj管理\JSA_AMIS_20179999\ZZ_個人フォルダ\jiang\AMISDB" 
# =============================================================

$downloadPath = "$env:USERPROFILE\Downloads"
$today        = Get-Date -Format "yyyy-MM-dd"

# 本地目录路径
$dayFolder = Join-Path $archivePath $today
$apFolder  = Join-Path $dayFolder "AP"
$rdsFolder = Join-Path $dayFolder "RDS"

# 创建本地目录
New-Item -ItemType Directory -Force -Path $apFolder | Out-Null
New-Item -ItemType Directory -Force -Path $rdsFolder | Out-Null

Write-Host "正在扫描 Downloads 文件夹..."

# 获取 20 分钟内修改过的文件
$timeLimit = (Get-Date).AddMinutes(-20) 
$files = Get-ChildItem $downloadPath -File |
    Where-Object { $_.LastWriteTime -gt $timeLimit } |
    Sort-Object LastWriteTime

Write-Host "共发现 $($files.Count) 个在指定时间内修改的文件："
foreach ($f in $files) {
    Write-Host " - $($f.Name) (修改时间: $($f.LastWriteTime))"
}

# 检查数量
if ($files.Count -ne 4) {
    Write-Host "`n[警告] 找到的文件数量是 $($files.Count) 个，不是4个。脚本停止运行。" -ForegroundColor Yellow
    Read-Host "按回车键退出..."
    exit
}

# 智能移动并修复文件名
function Move-AndCleanFileName($fileObject, $destinationFolder) {
    $cleanName = $fileObject.Name -replace '\s*[\(_]\d+[\)]*\.', '.'
    $targetPath = Join-Path $destinationFolder $cleanName
    Move-Item -Path $fileObject.FullName -Destination $targetPath -Force
    Write-Host " -> 已移至 $cleanName -> $destinationFolder" -ForegroundColor Gray
    return $targetPath
}

# 1. 移动文件并修复文件名
Write-Host "`n正在对文件进行去尾巴处理并分类移动..." -ForegroundColor Cyan
$movedFiles = @()
$movedFiles += Move-AndCleanFileName $files[0] $apFolder
$movedFiles += Move-AndCleanFileName $files[1] $apFolder
$movedFiles += Move-AndCleanFileName $files[2] $rdsFolder
$movedFiles += Move-AndCleanFileName $files[3] $rdsFolder

Write-Host "本地桌面分类且文件名修复完成！" -ForegroundColor Green

# 【核心功能进化】2. 自动检索关键字 "err" 和 "ORA"
Write-Host "`n[🔍] 正在自动检索文件错误 (关键字: err, ORA)..." -ForegroundColor Cyan
$hasError = $false

foreach ($filePath in $movedFiles) {
    $fileName = Split-Path $filePath -Leaf
    
    # Select-String 默认不区分大小写，同时查找两个关键字
    # 针对可能存在的特殊编码（如日文/中文日志），加入 -Encoding utf8 或 default 确保不乱码
    $matches = Select-String -Path $filePath -Pattern "err", "ORA" -Encoding default
    
    if ($matches) {
        $hasError = $true
        Write-Host "`n[💥 警告] 在文件 [$fileName] 中发现了 $($matches.Count) 处疑似报错！" -ForegroundColor Red
        
        # 打印出前3处报错内容供预览
        $matches | Select-Object -First 3 | ForEach-Object {
            Write-Host "   -> 行 $($_.LineNumber): $($_.Line.Trim())" -ForegroundColor DarkRed
        }
        
        #哪个文件有错，就自动弹开哪一个
        Write-Host "   [🚀] 已自动为您打开该文件，请仔细核对。" -ForegroundColor Yellow
        Invoke-Item $filePath
    }
}

if (-not $hasError) {
    Write-Host "`n[✔] 完美！未检测到任何报错，可以安心收工！" -ForegroundColor Green
}

# 3. 自动同步到网络文件夹
Write-Host "`n正在检查网络文件夹连接..." -ForegroundColor Cyan
if (Test-Path $networkPath) {
    $networkTargetFolder = Join-Path $networkPath $today
    Write-Host "正在同步今天的文件到网络文件夹..." -ForegroundColor Cyan
    Copy-Item -Path $dayFolder -Destination $networkTargetFolder -Recurse -Force
    Write-Host "网络同步成功！已备份至: $networkTargetFolder" -ForegroundColor Green
} else {
    Write-Host "`n[错误] 无法连接到网络文件夹: $networkPath" -ForegroundColor Red
}

Read-Host "`n全部操作已结束，按回车键关闭窗口..."