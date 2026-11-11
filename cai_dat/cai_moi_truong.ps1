# Cài môi trường chạy Xưởng Lồng Tiếng sau khi bộ cài chép mã (Windows). Chạy lại được: phần đã có thì bỏ qua.
# - Python 3.12 do uv tải (không cần cài Python hệ thống), .venv cho Xưởng + CrawlTool, vieneu-env cho VieNeu
# - FFmpeg, Node.js (CrawlTool cần cho Douyin) qua winget nếu máy chưa có
# - .env: tạo từ .env.example, chỉ điền XLT_MAY / XLT_DATA_DIR / VIENEU_PYTHON khi đang trống
param(
    [Parameter(Mandatory = $true)][string]$ThuMucApp,
    [string]$ThuMucPhim = "",
    [switch]$TuDong   # app tự cập nhật: không hỏi, tự đóng cửa sổ
)

$ErrorActionPreference = "Stop"
# Inno truyền "D:\" thành D:" (dấu \ cuối nuốt dấu nháy): bỏ nháy thừa, trả lại \ cho ổ gốc.
$ThuMucPhim = $ThuMucPhim.Trim().TrimEnd('"')
if ($ThuMucPhim -match '^[A-Za-z]:$') { $ThuMucPhim += '\' }
$Host.UI.RawUI.WindowTitle = "Cài môi trường Xưởng Lồng Tiếng"
$log = Join-Path $ThuMucApp "cai_dat\cai_dat.log"
try { Start-Transcript -Path $log -Append | Out-Null } catch {}
$canhBao = New-Object System.Collections.Generic.List[string]

function Buoc([string]$s) { Write-Host ""; Write-Host "==> $s" -ForegroundColor Cyan }
function Chay([string]$moTa, [scriptblock]$lenh) {
    & $lenh
    if ($LASTEXITCODE) { throw "$moTa thất bại (mã $LASTEXITCODE). Xem $log" }
}
function CoLenh([string]$ten) { [bool](Get-Command $ten -ErrorAction SilentlyContinue) }
function LamMoiPath {
    $env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [Environment]::GetEnvironmentVariable("Path", "User")
}
function CaiWinget([string]$id, [string]$ten) {
    if (-not (CoLenh "winget")) { $canhBao.Add("Không có winget: tự cài $ten."); return }
    Write-Host "Cài $ten qua winget..."
    winget install --id $id -e --silent --accept-package-agreements --accept-source-agreements
    if ($LASTEXITCODE) { $canhBao.Add("Chưa cài được $ten (winget mã $LASTEXITCODE): tự cài rồi mở lại app.") }
    LamMoiPath
}

# Bộ cài Inno bật RedirectionGuard: tiến trình con không đi qua được junction do user tạo (lỗi 448
# "untrusted mount point"). uv đặt Python ở cpython-3.12.X-... kèm junction cpython-3.12-... và venv của uv
# luôn trỏ vào junction đó, nên venv tạo bằng "python -m venv" từ thư mục thật (pyvenv.cfg trỏ thẳng thư mục thật).
function PythonThat([string]$ban = "3.12") {
    Get-ChildItem (Join-Path $ThuMucApp "python") -Directory -Filter "cpython-$ban.*-windows-x86_64-none" -ErrorAction SilentlyContinue |
        Where-Object { -not $_.LinkType } |
        Sort-Object { [version]($_.Name -replace '^cpython-([0-9.]+)-.*$', '$1') } -Descending |
        Select-Object -First 1 | ForEach-Object { Join-Path $_.FullName "python.exe" }
}

function TaoVenv([string]$thuMuc, [string]$pyGoc = $script:pyThat) {
    $cfg = Join-Path $thuMuc "pyvenv.cfg"
    if (Test-Path $cfg) {
        $nha = ((Get-Content $cfg | Where-Object { $_ -match '^home\s*=' }) -replace '^home\s*=\s*', '').Trim()
        if ($nha -and (Test-Path -LiteralPath $nha) -and -not (Get-Item -LiteralPath $nha -Force).LinkType) { return }
        Write-Host "Tạo lại $thuMuc (venv cũ trỏ qua junction, bộ cài không chạy được)."
        Remove-Item -Recurse -Force $thuMuc
    }
    Chay "Tạo $thuMuc" { & $pyGoc -m venv --without-pip $thuMuc }
}

function DatKhoa([string]$tep, [string]$khoa, [string]$giaTri) {
    # Chỉ điền khi khóa chưa có hoặc đang trống: không ghi đè cấu hình user đã sửa.
    $dong = [System.Collections.Generic.List[string]]([IO.File]::ReadAllLines($tep, [Text.Encoding]::UTF8))
    for ($i = 0; $i -lt $dong.Count; $i++) {
        if ($dong[$i] -match "^\s*$([regex]::Escape($khoa))\s*=(.*)$") {
            if ($Matches[1].Trim()) { return }
            $dong[$i] = "$khoa=$giaTri"
            [IO.File]::WriteAllLines($tep, $dong, (New-Object Text.UTF8Encoding $false)); return
        }
    }
    $dong.Add("$khoa=$giaTri")
    [IO.File]::WriteAllLines($tep, $dong, (New-Object Text.UTF8Encoding $false))
}

try {
    $uv = @((Join-Path $ThuMucApp "uv\uv.exe"), (Join-Path $ThuMucApp "xuong\crawl\uv.exe")) | Where-Object { Test-Path $_ } | Select-Object -First 1
    if (-not $uv) { $uv = Join-Path $ThuMucApp "uv\uv.exe" }
    if (-not (Test-Path $uv)) { throw "Thiếu $uv (bộ cài hỏng?)" }
    $env:UV_PYTHON_INSTALL_DIR = Join-Path $ThuMucApp "python"
    $env:UV_LINK_MODE = "copy"
    # Bộ đệm gói đặt cạnh app (ổ đã chọn, thường là D) thay vì %LOCALAPPDATA% ổ C: PyTorch CUDA của VieNeu ~3 GB,
    # cập nhật lần sau dùng lại không tải lại. Bản patch không đụng thư mục uv\.
    if (-not $env:UV_CACHE_DIR) { $env:UV_CACHE_DIR = Join-Path $ThuMucApp "uv\cache" }
    # Chỉ dùng Python do uv tải: Python lạ trong PATH (vd venv của hermes-agent) làm uv dừng với lỗi 448.
    $env:UV_PYTHON_PREFERENCE = "only-managed"

    Buoc "Python 3.12 và môi trường .venv"
    $venv = Join-Path $ThuMucApp ".venv"
    $py = Join-Path $venv "Scripts\python.exe"
    $script:pyThat = PythonThat
    # Dưới RedirectionGuard uv tải xong Python nhưng báo lỗi 448 khi tạo junction: bỏ qua mã lỗi, kiểm thư mục thật.
    if (-not $script:pyThat) { & $uv python install 3.12; $script:pyThat = PythonThat }
    if (-not $script:pyThat) { throw "Không thấy Python 3.12 trong $(Join-Path $ThuMucApp "python") sau khi tải." }
    TaoVenv $venv

    Buoc "Thư viện Xưởng + CrawlTool (requirements.txt)"
    Chay "Cài requirements" { & $uv pip install --python $py -r (Join-Path $ThuMucApp "requirements.txt") }

    if (CoLenh "nvidia-smi") {
        Buoc "Thư viện CUDA cho Whisper (GPU NVIDIA)"
        Chay "Cài CUDA" { & $uv pip install --python $py nvidia-cublas-cu12 nvidia-cudnn-cu12 }
    } else {
        $canhBao.Add("Không thấy GPU NVIDIA (nvidia-smi): Whisper sẽ rất chậm hoặc lỗi trên CPU.")
    }

    Buoc "VieNeu (đọc giọng Việt), môi trường riêng"
    $vn = Join-Path $ThuMucApp "vieneu-env"
    $vpy = Join-Path $vn "Scripts\python.exe"
    TaoVenv $vn

    # CrawlTool tự "uv sync" vào %LOCALAPPDATA%\CrawlTool\venv lần đầu mở. Nếu app được bộ cài mở (cuối cài đặt, sau tự
    # cập nhật) thì uv tạo venv trỏ qua junction và CrawlTool lỗi 448, nên máy chưa có venv thì tạo sẵn từ Python thật
    # đúng bản trong .python-version của base; uv sync dùng lại venv này. Venv đã có thì để nguyên (CrawlTool chỉ sync
    # khi đổi base, xóa đi là mất thư viện).
    $crawlVenv = Join-Path $env:LOCALAPPDATA "CrawlTool\venv"
    $baseZip = Join-Path $ThuMucApp "xuong\crawl\base.zip"
    if (-not (Test-Path (Join-Path $crawlVenv "pyvenv.cfg")) -and (Test-Path $baseZip)) {
        Buoc "Python cho CrawlTool"
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $z = [IO.Compression.ZipFile]::OpenRead($baseZip)
        try {
            $e = $z.Entries | Where-Object { $_.FullName -match "^[^/]+/\.python-version$" } | Select-Object -First 1
            $banCrawl = if ($e) { (New-Object IO.StreamReader($e.Open())).ReadToEnd().Trim() } else { "3.11" }
        } finally { $z.Dispose() }
        $pyCrawl = PythonThat $banCrawl
        if (-not $pyCrawl) { & $uv python install $banCrawl; $pyCrawl = PythonThat $banCrawl }
        if ($pyCrawl) { TaoVenv $crawlVenv $pyCrawl }
        else { $canhBao.Add("Chưa tải được Python $banCrawl cho CrawlTool: mở app bằng biểu tượng Desktop trước khi bấm Tìm phim.") }
    }
    Chay "Cài vieneu" { & $uv pip install --python $vpy vieneu }
    if (CoLenh "nvidia-smi") {
        # VieNeu đọc bằng card (PyTorch CUDA 12.8, ~3 GB): tóm tắt 216 đoạn trên CPU mất ~50 phút. Lỗi thì app vẫn đọc bằng CPU.
        Buoc "VieNeu đọc bằng card đồ họa (GPU NVIDIA)"
        try {
            Chay "Cài VieNeu GPU" { & $uv pip install --python $vpy "vieneu[cuda]" --extra-index-url "https://download.pytorch.org/whl/cu128" --index-strategy unsafe-best-match }
        } catch {
            $canhBao.Add("Chưa cài được VieNeu chạy bằng card đồ họa: giọng Việt vẫn đọc bằng CPU (chậm hơn). $_")
        }
    }

    Buoc "FFmpeg"
    if (-not (CoLenh "ffmpeg") -or -not (CoLenh "ffprobe")) { CaiWinget "Gyan.FFmpeg" "FFmpeg" }
    else { Write-Host "Đã có: $((Get-Command ffmpeg).Source)" }

    Buoc "Node.js (CrawlTool cần để crawl Douyin, Zhihu)"
    if (-not (CoLenh "node")) { CaiWinget "OpenJS.NodeJS.LTS" "Node.js LTS" } else { Write-Host "Đã có: $(node --version)" }

    Buoc "Google Chrome / Cốc Cốc"
    $chrome = @("$env:ProgramFiles\Google\Chrome\Application\chrome.exe", "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe",
                "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe") | Where-Object { Test-Path $_ } | Select-Object -First 1
    if ($chrome) { Write-Host "Đã có Chrome." } else { $canhBao.Add("Chưa có Google Chrome: Douyin (Xưởng và CrawlTool) cần Chrome. Tải ở google.com/chrome.") }

    Buoc "Gói OCR của Windows"
    try {
        $null = [Windows.Media.Ocr.OcrEngine, Windows.Foundation, ContentType = WindowsRuntime]
        $ngonNgu = [Windows.Media.Ocr.OcrEngine]::AvailableRecognizerLanguages | ForEach-Object { $_.LanguageTag }
        Write-Host "Có OCR: $($ngonNgu -join ', ')"
        if (-not ($ngonNgu | Where-Object { $_ -like "zh*" })) {
            $cai = $false
            if (-not $TuDong) {
                $tl = Read-Host "Máy chưa có gói đọc chữ (OCR) tiếng Trung, bước Đọc sub phim Trung cần gói này. Cài luôn? (Windows hỏi quyền quản trị) [Y/n]"
                $cai = ($tl -eq "" -or $tl -match "^[yYcC]")
            }
            if ($cai) {
                try {
                    Start-Process powershell -Verb RunAs -Wait -ArgumentList "-NoProfile -Command Add-WindowsCapability -Online -Name 'Language.OCR~~~zh-CN~0.0.1.0'"
                    Write-Host "Đã chạy cài gói OCR tiếng Trung."
                } catch { $canhBao.Add("Chưa cài được gói OCR tiếng Trung: vào Cài đặt > Lồng tiếng > Gói đọc chữ (OCR) trong app để cài.") }
            } else {
                $canhBao.Add("Thiếu OCR tiếng Trung: phim Trung sẽ dừng ở bước Đọc sub. Cài ở Cài đặt > Lồng tiếng > Gói đọc chữ (OCR) trong app.")
            }
        }
    } catch { $canhBao.Add("Không kiểm được gói OCR của Windows.") }

    Buoc "Cấu hình .env"
    $envTep = Join-Path $ThuMucApp ".env"
    if (-not (Test-Path $envTep)) { Copy-Item (Join-Path $ThuMucApp ".env.example") $envTep; Write-Host "Đã tạo .env từ .env.example." }
    DatKhoa $envTep "XLT_MAY" "win"
    if ($ThuMucPhim) {
        DatKhoa $envTep "XLT_DATA_DIR" $ThuMucPhim
        if (-not (Test-Path -LiteralPath $ThuMucPhim)) { New-Item -ItemType Directory -Force $ThuMucPhim | Out-Null }  # New-Item -Force lỗi với gốc ổ (D:\)
    }
    DatKhoa $envTep "VIENEU_PYTHON" $vpy
    $khoa = Get-Content $envTep -Encoding UTF8 | Where-Object { $_ -match "^GEMINI_API_KEY=\s*$" }
    if ($khoa) { $canhBao.Add("Chưa có GEMINI_API_KEY: điền khóa vào $envTep để dịch.") }

    Buoc "Kiểm nhanh"
    Push-Location $ThuMucApp  # Python tìm gói xuong theo thư mục hiện hành: phải đứng trong thư mục app
    try { Chay "Nạp mã Xưởng" { & $py -c "import xuong, xuong.app, xuong.crawl; print('Xưởng', xuong.PHIEN_BAN, '+ CrawlTool', xuong.crawl.ct.APP_VERSION)" } } finally { Pop-Location }

    Write-Host ""
    Write-Host "XONG. Mở app bằng biểu tượng Xưởng Lồng Tiếng trên Desktop." -ForegroundColor Green
    if ($canhBao.Count) {
        Write-Host "Cần lưu ý:" -ForegroundColor Yellow
        $canhBao | ForEach-Object { Write-Host " - $_" -ForegroundColor Yellow }
        if ($TuDong) { Start-Sleep -Seconds 6 } else { Read-Host "Bấm Enter để đóng" }
    } else { Start-Sleep -Seconds 4 }
    exit 0
} catch {
    Write-Host ""
    Write-Host "LỖI: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Sửa xong thì chạy lại: Start menu > Cài lại môi trường Xưởng." -ForegroundColor Red
    if ($TuDong) { Start-Sleep -Seconds 20 } else { Read-Host "Bấm Enter để đóng" }
    exit 1
} finally {
    try { Stop-Transcript | Out-Null } catch {}
}
