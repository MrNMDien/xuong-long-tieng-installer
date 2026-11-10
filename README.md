# Bộ cài Xưởng Lồng Tiếng (Windows)

Repo này chỉ chứa phần đóng gói. Mã nằm ở repo riêng `MrNMDien/xuong-long-tieng` (bản sao của
`phucphan2306-ui/xuong-long-tieng`, đã gộp CrawlTool vào `xuong/crawl`). Bộ cài chỉ có phần chạy trên Windows:
không gói `mac/`, `xuong/nghe_mlx.py`, `xuong/ocr_mac.py`, dữ liệu mẫu `mau_chuan/`, test và tài liệu nội bộ.

## Build
Cần: Git, [Inno Setup 6](https://jrsoftware.org/isinfo.php), [uv](https://docs.astral.sh/uv/), repo
`xuong-long-tieng` ở thư mục bên cạnh và `MediaCrawler` (base của CrawlTool) đã commit sạch.

```powershell
powershell -ExecutionPolicy Bypass -File build.ps1
# tùy chọn: -Xuong <đường dẫn repo Xưởng> -Ref <nhánh/commit> -MediaCrawler <đường dẫn> -Iscc <ISCC.exe>
```
Kết quả: `dist\XuongLongTieng-Setup-<phiên bản>-<commit>.exe`. Không có `.env` nào trong bộ cài (build dừng nếu thấy).

## Bộ cài làm gì
1. Chép mã vào `%LOCALAPPDATA%\Programs\XuongLongTieng` (không cần quyền quản trị), hỏi thư mục dữ liệu phim.
2. Chạy `cai_dat\cai_moi_truong.ps1` trong cửa sổ PowerShell:
   - uv tải Python 3.12, tạo `.venv` và cài `requirements.txt` (Xưởng + CrawlTool); có GPU NVIDIA thì cài thêm CUDA cho Whisper,
   - `vieneu-env` riêng cho VieNeu,
   - FFmpeg và Node.js qua winget nếu thiếu; kiểm Chrome và gói OCR tiếng Trung của Windows,
   - tạo `.env` từ `.env.example`, điền `XLT_MAY`, `XLT_DATA_DIR`, `VIENEU_PYTHON` nếu còn trống.
3. Tạo lối tắt Desktop/Start menu: **Xưởng Lồng Tiếng**, **Tìm phim (CrawlTool)**, **Cài lại môi trường Xưởng**.

Cài bản mới đè lên bản cũ giữ nguyên `.env`, môi trường Python và dữ liệu. Gỡ cài giữ `.env` và dữ liệu phim.
Khóa API (Gemini, Telegram, Supabase) tự điền vào `.env` sau khi cài.
