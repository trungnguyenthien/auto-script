# install_commitlint_husky.sh

Script tự động cài đặt và cấu hình bộ đôi **Commitlint** và **Husky** cho dự án Git nhằm chuẩn hóa các thông điệp commit theo chuẩn Conventional Commits.

## Chức năng
- **Kiểm tra môi trường:** Tự động phát hiện và cài đặt Node.js và npm thông qua Homebrew nếu hệ thống chưa có.
- **Cài đặt thư viện toàn cục (Global):**
  - Cài đặt `@commitlint/cli@19.8.1` và `@commitlint/config-conventional@19.8.1`.
  - Cài đặt `husky@9.1.7`.
- **Khởi tạo cấu hình dự án:**
  - Tạo tệp `commitlint.config.cjs` kế thừa cấu hình chuẩn `conventional`.
  - Tự động phát hiện và tạo tệp `package.json` cơ bản nếu chưa tồn tại (tiện lợi cho các dự án Native iOS/Android hoặc Flutter).
  - Tự động chèn thêm script `"prepare": "husky"` vào `package.json` nếu chưa có.
- **Thiết lập Git Hooks (Husky):**
  - Khởi tạo thư mục quản lý `.husky/`.
  - Tạo cấu hình hook `commit-msg` để chạy lệnh kiểm tra commit message (`npx --no-install commitlint --edit "$1"`).
  - Tạo các mẫu hook rỗng sẵn sàng sử dụng: `pre-commit`, `pre-push`, `post-commit`, `prepare-commit-msg`.
  - Cấp quyền thực thi (`chmod +x`) cho toàn bộ thư mục và tệp hook trong `.husky/`.

## Cách sử dụng

### 1. Chạy trực tiếp từ tệp script cục bộ:
```bash
chmod +x install_commitlint_husky.sh
./install_commitlint_husky.sh
```

### 2. Tải và chạy nhanh qua mạng:
```bash
curl -fsSL https://raw.githubusercontent.com/trungnguyenthien/auto-script/refs/heads/main/install_commitlint_husky.sh -o install_commitlint_husky.sh && chmod +x install_commitlint_husky.sh && ./install_commitlint_husky.sh && rm install_commitlint_husky.sh
```

## Cách kiểm tra hoạt động

1. **Kiểm tra phiên bản cài đặt:**
   ```bash
   commitlint --version   # Nên trả về 19.8.1
   husky --version        # Nên trả về 9.1.7
   ls -la .husky/         # Kiểm tra xem các file hooks đã được tạo chưa
   ```

2. **Kiểm tra tính năng xác thực commit:**
   - Thử commit với tin nhắn không đúng chuẩn:
     ```bash
     git add .
     git commit -m "update code" # Lệnh này sẽ bị từ chối và báo lỗi format
     ```
   - Thử commit với tin nhắn đúng chuẩn:
     ```bash
     git commit -m "feat: add user authentication module" # Lệnh này sẽ thành công
     ```

## Cấu hình và Yêu cầu hệ thống
- **Hệ điều hành:** macOS (có sẵn công cụ quản lý gói Homebrew).
- **Yêu cầu Git:** Dự án phải được khởi tạo Git trước khi chạy script (`git init`).
- **Quyền hạn:** Script sử dụng lệnh `sudo npm install -g` nên sẽ yêu cầu bạn nhập mật khẩu quản trị (sudo password) để cài đặt các package global.
