# Phát hành một bản Xưởng Lồng Tiếng lên GitHub Releases, một lệnh:
#   kiểm repo Xưởng đã commit → push mã → build file cài tổng + file patch → push repo bộ cài → tạo release → kiểm tải về.
# Trước khi chạy: tăng PHIEN_BAN trong xuong/__init__.py và thêm mục đúng số đó vào xuong/tai_nguyen/cap_nhat.json.
# Chạy: powershell -ExecutionPolicy Bypass -File phat_hanh.ps1
param(
    [string]$Xuong = (Join-Path $PSScriptRoot "..\xuong-long-tieng"),
    [string]$Repo = "MrNMDien/xuong-long-tieng-installer"
)

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot
$Xuong = (Resolve-Path $Xuong).Path
function G([string]$repo) { $o = & git -C $repo @args; if ($LASTEXITCODE) { throw "git -C $repo $($args -join ' ') lỗi" }; $o }

if (G $Xuong status --porcelain --untracked-files=no) { throw "Repo Xưởng còn thay đổi chưa commit." }
$m = Select-String -Path (Join-Path $Xuong "xuong\__init__.py") -Pattern 'PHIEN_BAN\s*=.*"([0-9]+\.[0-9]+\.[0-9]+)"'
$ver = $m.Matches[0].Groups[1].Value
$tag = "v$ver"
$ErrorActionPreference = "Continue"  # gh in "release not found" ra stderr: là kết quả mong đợi, không phải lỗi
& gh release view $tag -R $Repo 2>$null | Out-Null
$daCo = $LASTEXITCODE -eq 0
$ErrorActionPreference = "Stop"
if ($daCo) { throw "Bản $ver đã phát hành: tăng PHIEN_BAN và thêm mục vào cap_nhat.json." }
$ghiChu = (Get-Content (Join-Path $Xuong "xuong\tai_nguyen\cap_nhat.json") -Raw -Encoding UTF8 | ConvertFrom-Json) |
    Where-Object { $_.phien_ban -eq $ver } | Select-Object -First 1
if (-not $ghiChu) { throw "cap_nhat.json chưa có mục cho bản $ver." }

Write-Host "==> Push mã Xưởng ($ver)"
$nhanh = (G $Xuong rev-parse --abbrev-ref HEAD).Trim()
G $Xuong push origin $nhanh | Out-Null

Write-Host "==> Build"
& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "build.ps1") -Xuong $Xuong
if ($LASTEXITCODE) { throw "Build lỗi." }
$sha = (G $Xuong rev-parse --short HEAD).Trim()
$ban = Get-Content (Join-Path $PSScriptRoot "dist\ban-$ver-$sha.json") -Raw | ConvertFrom-Json
$setup = $ban | Where-Object Loai -eq "Setup"
$patch = $ban | Where-Object Loai -eq "Patch"

Write-Host "==> Push repo bộ cài"
if (G $PSScriptRoot status --porcelain) {
    G $PSScriptRoot add -A | Out-Null
    G $PSScriptRoot commit -q -m "Phát hành $tag" | Out-Null
}
G $PSScriptRoot push origin HEAD | Out-Null

Write-Host "==> Tạo release $tag"
$dong = ($ghiChu.muc | ForEach-Object { "- $_" }) -join "`n"
$notes = @"
## Xưởng Lồng Tiếng $ver ($($ghiChu.ngay))

$dong

### Tải về
- **$(Split-Path $setup.Tep -Leaf)**: file cài tổng, cho máy chưa cài.
- **$(Split-Path $patch.Tep -Leaf)**: cho máy đã cài muốn cập nhật tay (dự phòng khi tự cập nhật lỗi). App cũng tự cập nhật bằng file này.

Cài đè giữ nguyên dữ liệu phim, .env và cài đặt.

sha256: $($setup.Sha256)
sha256-patch: $($patch.Sha256)
"@
$tepNotes = Join-Path $PSScriptRoot "dist\notes-$ver.md"
[IO.File]::WriteAllText($tepNotes, $notes, (New-Object Text.UTF8Encoding $false))
& gh release create $tag $setup.Tep $patch.Tep -R $Repo --title "Xưởng Lồng Tiếng $ver" --notes-file $tepNotes --latest
if ($LASTEXITCODE) { throw "Tạo release lỗi." }

Write-Host "==> Kiểm tải về như app (không đăng nhập)"
$rel = Invoke-RestMethod "https://api.github.com/repos/$Repo/releases/latest" -Headers @{ "User-Agent" = "XuongLongTieng-phat-hanh" }
if ($rel.tag_name -ne $tag) { throw "Release mới nhất là $($rel.tag_name), không phải $tag." }
foreach ($b in $setup, $patch) {
    $a = $rel.assets | Where-Object name -eq (Split-Path $b.Tep -Leaf)
    $tam = Join-Path $env:TEMP $a.name
    Invoke-WebRequest $a.browser_download_url -OutFile $tam -UseBasicParsing -Headers @{ "User-Agent" = "XuongLongTieng-phat-hanh" }
    $h = (Get-FileHash $tam -Algorithm SHA256).Hash.ToLower()
    Remove-Item $tam
    if ($h -ne $b.Sha256) { throw "$($a.name): tải về không khớp SHA-256." }
    Write-Host "  OK $($a.name)"
}
Write-Host "Đã phát hành ${tag}: https://github.com/$Repo/releases/tag/$tag" -ForegroundColor Green
