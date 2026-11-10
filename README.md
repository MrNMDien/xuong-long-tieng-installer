# Xưởng Lồng Tiếng – bộ cài Windows

Tải ở [Releases](../../releases/latest). Mỗi bản có 2 file:

| File | Dùng khi |
|---|---|
| `XuongLongTieng-Setup-<bản>.exe` | **File cài tổng**: máy chưa cài. Luôn là bản mới nhất. |
| `XuongLongTieng-Patch-<bản>.exe` | **File patch**: máy đã cài muốn cập nhật tay (dự phòng khi tự cập nhật lỗi). Nhẹ, chỉ chứa mã. |

App tự cập nhật bắt buộc: mở app là kiểm bản mới, tự tải file patch, kiểm SHA-256, cài im lặng rồi mở lại.
Cài đè giữ nguyên dữ liệu phim, `.env` và cài đặt. Đăng nhập bằng tài khoản CrawlTool được cấp.

Windows có thể báo "Windows protected your PC" vì file chưa ký số: bấm **More info → Run anyway**.

## Phát hành (người làm app)
1. Tăng `PHIEN_BAN` trong `xuong/__init__.py`, thêm mục cùng số vào `xuong/tai_nguyen/cap_nhat.json`, commit.
2. `powershell -ExecutionPolicy Bypass -File phat_hanh.ps1`

Script push mã, build cả 2 file (`build.ps1`, Inno Setup + uv), push repo này, tạo release kèm ghi chú và SHA-256,
rồi tải lại như app để kiểm. Cần: Git, `gh` đã đăng nhập, Inno Setup 6, uv, repo `xuong-long-tieng` cạnh thư mục này và
`MediaCrawler` (base của CrawlTool) đã commit sạch.
