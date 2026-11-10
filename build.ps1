# Build bộ cài XuongLongTieng-Setup-<phiên bản>-<commit>.exe (chỉ Windows).
# Chạy: powershell -ExecutionPolicy Bypass -File build.ps1   (kết quả ở dist\)
# Lấy mã Xưởng đã commit ở repo xuong-long-tieng (mặc định thư mục bên cạnh), bỏ phần Mac và đồ phát triển,
# gói kèm base MediaCrawler (base.zip + base.sha) và uv.exe cho CrawlTool, rồi biên dịch bằng Inno Setup 6.
param(
    [string]$Xuong = (Join-Path $PSScriptRoot "..\xuong-long-tieng"),
    [string]$Ref = "HEAD",
    [string]$MediaCrawler = "D:\Claude\Crawltool\MediaCrawler",
    [string]$Iscc = ""
)

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot
$Xuong = (Resolve-Path $Xuong).Path
$MediaCrawler = (Resolve-Path $MediaCrawler).Path

function G([string]$repo) { $o = & git -C $repo @args; if ($LASTEXITCODE) { throw "git -C $repo $($args -join ' ') lỗi" }; $o }

# Chỉ gói mã đã commit: thay đổi chưa commit sẽ không có trong bộ cài, báo trước cho khỏi nhầm.
if ($Ref -eq "HEAD" -and (G $Xuong status --porcelain --untracked-files=no)) {
    throw "Repo Xưởng còn thay đổi chưa commit: commit rồi build lại."
}
if (G $MediaCrawler status --porcelain --untracked-files=no) { throw "MediaCrawler còn thay đổi chưa commit." }

$build = Join-Path $PSScriptRoot "build"
$stage = Join-Path $build "stage"
if (Test-Path $build) { Remove-Item -Recurse -Force $build }
New-Item -ItemType Directory -Force $stage | Out-Null

Write-Host "==> Lấy mã Xưởng ($Ref), chỉ phần Windows"
$bo = @("mac", "mau_chuan", "tests", "xuong/nghe_mlx.py", "xuong/ocr_mac.py", "AGENTS.md", "CLAUDE.md",
        "GIAO-VIEC-GPT.md", "NHAT-KY.md", "hoc-tu-cac-tool-long-tieng.md", "tool-long-tieng-tuong-tu-tren-github.md")
$zip = Join-Path $build "xuong.zip"
G $Xuong archive --format=zip -o $zip $Ref -- . ($bo | ForEach-Object { ":(exclude)$_" }) | Out-Null
Expand-Archive -Path $zip -DestinationPath $stage
foreach ($cam in ".env", ".env.chung") {
    if (Test-Path (Join-Path $stage $cam)) { throw "$cam không được nằm trong bộ cài (chứa khóa API)." }
}

Write-Host "==> Base MediaCrawler + uv.exe cho CrawlTool"
$crawl = Join-Path $stage "xuong\crawl"
if (-not (Test-Path (Join-Path $crawl "crawl_tool.py"))) { throw "Mã Xưởng chưa có xuong/crawl (chưa gộp CrawlTool?)." }
G $MediaCrawler archive --format=zip --prefix=MediaCrawler/ -o (Join-Path $crawl "base.zip") HEAD | Out-Null
[IO.File]::WriteAllText((Join-Path $crawl "base.sha"), (G $MediaCrawler rev-parse HEAD).Trim())
$uv = (Get-Command uv -ErrorAction SilentlyContinue).Source
if (-not $uv) { throw "Không thấy uv.exe trong PATH (cài: winget install astral-sh.uv)." }
Copy-Item $uv (Join-Path $crawl "uv.exe")

Copy-Item -Recurse (Join-Path $PSScriptRoot "cai_dat") (Join-Path $stage "cai_dat")

$m = Select-String -Path (Join-Path $stage "xuong\__init__.py") -Pattern 'PHIEN_BAN\s*=.*"([0-9]+\.[0-9]+\.[0-9]+)"'
if (-not $m) { throw "Không đọc được PHIEN_BAN trong xuong/__init__.py" }
$ver = $m.Matches[0].Groups[1].Value
$sha = (G $Xuong rev-parse --short $Ref).Trim()

if (-not $Iscc) {
    $Iscc = @("$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe", "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
              "$env:ProgramFiles\Inno Setup 6\ISCC.exe") | Where-Object { Test-Path $_ } | Select-Object -First 1
}
if (-not $Iscc) { throw "Không thấy Inno Setup 6 (cài: winget install JRSoftware.InnoSetup)." }

Write-Host "==> Biên dịch bộ cài $ver ($sha)"
& $Iscc "/Qp" "/DAppVersion=$ver" "/DBuildSha=$sha" "/DStage=$stage" (Join-Path $PSScriptRoot "setup.iss")
if ($LASTEXITCODE) { throw "Inno Setup lỗi (mã $LASTEXITCODE)." }
$exe = Get-ChildItem (Join-Path $PSScriptRoot "dist") -Filter "XuongLongTieng-Setup-$ver-$sha.exe" | Select-Object -First 1
$sha = (Get-FileHash $exe.FullName -Algorithm SHA256).Hash.ToLower()
[IO.File]::WriteAllText("$($exe.FullName).sha256", "sha256: $sha")
Write-Host ("Xong: {0} ({1:N0} MB)" -f $exe.FullName, ($exe.Length / 1MB)) -ForegroundColor Green
Write-Host "sha256: $sha  (dán dòng này vào ghi chú release để app kiểm khi tự cập nhật)"
