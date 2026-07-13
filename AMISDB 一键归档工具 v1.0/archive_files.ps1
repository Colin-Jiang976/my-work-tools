$downloadPath = "$env:USERPROFILE\Downloads"
# 你的本地文件夹路径
$archivePath  = "C:\Users\Folder\AMISDB"
# 你的网络文件夹路径
$networkPath  = "\\192.168.1.100\Folder\AMISDB" 

# 今天日期
$today = Get-Date -Format "yyyy-MM-dd"

# 本地目录路径
$dayFolder = Join-Path $archivePath $today
$apFolder  = Join-Path $dayFolder "AP"
$rdsFolder = Join-Path $dayFolder "RDS"

# 创建本地目录
New-Item -ItemType Directory -Force -Path $apFolder | Out-Null
New-Item -ItemType Directory -Force -Path $rdsFolder | Out-Null

Write-Host "正在扫描 Downloads 文件夹..."

# 获取今天内修改过的文件
$timeLimit = (Get-Date).AddMinutes(-1440) 
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
    # 使用正则表达式去掉文件名末尾的 (1), (2), _1, _2 以及空格
    $cleanName = $fileObject.Name -replace '\s*[\(_]\d+[\)]*\.', '.'
    
    $targetPath = Join-Path $destinationFolder $cleanName
    
    # 移动文件，并重命名为干净的名字
    Move-Item -Path $fileObject.FullName -Destination $targetPath -Force
    Write-Host " -> 已移至 $cleanName -> $destinationFolder" -ForegroundColor Gray
}

# 1. 移动文件到本地归档目录并自动修复文件名
Write-Host "`n正在对文件进行去尾巴处理并分类移动..." -ForegroundColor Cyan

# 前两个放AP，后两个放RDS
Move-AndCleanFileName $files[0] $apFolder
Move-AndCleanFileName $files[1] $apFolder
Move-AndCleanFileName $files[2] $rdsFolder
Move-AndCleanFileName $files[3] $rdsFolder

Write-Host "本地桌面分类且文件名修复完成！" -ForegroundColor Green

# 2. 自动打开这 4 个文件供人工 check
Write-Host "`n[🚀] 正在为您自动打开这 4 个文件..." -ForegroundColor Cyan
Invoke-Item $newApFile1
Invoke-Item $newApFile2
Invoke-Item $newRdsFile1
Invoke-Item $newRdsFile2

# 3. 自动同步到网络文件夹
Write-Host "`n正在检查网络文件夹连接..." -ForegroundColor Cyan
if (Test-Path $networkPath) {
    $networkTargetFolder = Join-Path $networkPath $today
    Write-Host "正在同步今天的文件到网络文件夹..." -ForegroundColor Cyan
    Copy-Item -Path $dayFolder -Destination $networkTargetFolder -Recurse -Force
    Write-Host "网络同步成功！已备份至: $networkTargetFolder" -ForegroundColor Green
} else {
    Write-Host "`n[错误] 无法连接到网络文件夹: $networkPath" -ForegroundColor Red
    Write-Host "请检查网络连接、VPN是否开启，或网络路径是否正确。" -ForegroundColor Red
}

Read-Host "`n全部操作已结束，按回车键关闭窗口..."