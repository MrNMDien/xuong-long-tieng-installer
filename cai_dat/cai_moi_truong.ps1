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

    Buoc "Python 3.12 và môi trường .venv"
    $venv = Join-Path $ThuMucApp ".venv"
    $py = Join-Path $venv "Scripts\python.exe"
    if (-not (Test-Path $py)) { Chay "Tạo .venv" { & $uv venv --python 3.12 $venv } }

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
    if (-not (Test-Path $vpy)) { Chay "Tạo vieneu-env" { & $uv venv --python 3.12 $vn } }
    Chay "Cài vieneu" { & $uv pip install --python $vpy vieneu }

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
            $canhBao.Add("Thiếu OCR tiếng Trung: Settings > Time & language > Language & region > thêm Chinese (Simplified), tích Optical character recognition.")
        }
    } catch { $canhBao.Add("Không kiểm được gói OCR của Windows.") }

    Buoc "Cấu hình .env"
    $envTep = Join-Path $ThuMucApp ".env"
    if (-not (Test-Path $envTep)) { Copy-Item (Join-Path $ThuMucApp ".env.example") $envTep; Write-Host "Đã tạo .env từ .env.example." }
    DatKhoa $envTep "XLT_MAY" "win"
    if ($ThuMucPhim) {
        DatKhoa $envTep "XLT_DATA_DIR" $ThuMucPhim
        New-Item -ItemType Directory -Force $ThuMucPhim | Out-Null
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
