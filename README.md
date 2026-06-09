# Auto Script

> Bộ các công cụ và script tự động hóa cài đặt môi trường, quản lý giả lập và tiện ích phát triển trên macOS/iOS/Android.

Mỗi công cụ đều có tài liệu hướng dẫn chi tiết đi kèm dưới định dạng `.md`. Bạn có thể tải và chạy trực tiếp từng công cụ qua mạng bằng lệnh `curl` mà không cần clone cả kho lưu trữ.

---

## 📋 Danh sách công cụ

### 1. Cài đặt Môi trường (Environment Setup)

#### 🚀 [Cài đặt Môi trường Flutter](install_flutter_env.md) (`install_flutter_env.sh`)

Tự động cài đặt và cấu hình hoàn chỉnh môi trường phát triển ứng dụng Flutter trên macOS chạy chip Apple Silicon (ARM64).

```sh
curl -fsSL https://raw.githubusercontent.com/trungnguyenthien/auto-script/refs/heads/main/install_flutter_env.sh -o install_flutter_env.sh && chmod +x install_flutter_env.sh && ./install_flutter_env.sh && rm install_flutter_env.sh
```

#### 💎 [Cài đặt Ruby mới nhất](install_ruby.md) (`install_ruby.sh`)

Tự động cài đặt, cập nhật và thiết lập cấu hình biến môi trường cho phiên bản Ruby mới nhất qua Homebrew cùng với Bundler trên macOS.

```sh
curl -fsSL https://raw.githubusercontent.com/trungnguyenthien/auto-script/refs/heads/main/install_ruby.sh -o install_ruby.sh && chmod +x install_ruby.sh && ./install_ruby.sh && rm install_ruby.sh
```

#### 🦊 [Cài đặt Commitlint & Husky](install_commitlint_husky.md) (`install_commitlint_husky.sh`)

Tự động cài đặt và cấu hình bộ đôi Commitlint & Husky cho dự án Git nhằm chuẩn hóa các thông điệp commit theo chuẩn Conventional Commits.

```sh
curl -fsSL https://raw.githubusercontent.com/trungnguyenthien/auto-script/refs/heads/main/install_commitlint_husky.sh -o install_commitlint_husky.sh && chmod +x install_commitlint_husky.sh && ./install_commitlint_husky.sh && rm install_commitlint_husky.sh
```

---

### 2. Quản lý Giả lập iOS (iOS Simulator Management)

#### 📱 [Tạo & Quản lý Giả lập iOS Hàng loạt](install_ios_simulators.md) (`install_ios_simulators.sh`)

Giao diện dòng lệnh tương tác hỗ trợ quét môi trường hệ thống, tự động tạo hàng loạt các thiết bị giả lập iOS, đồng thời cung cấp menu quản lý vận hành (bật/tắt/factory reset) nhanh chóng.

```sh
curl -fsSL https://raw.githubusercontent.com/trungnguyenthien/auto-script/refs/heads/main/install_ios_simulators.sh -o install_ios_simulators.sh && chmod +x install_ios_simulators.sh && ./install_ios_simulators.sh && rm install_ios_simulators.sh
```

---

### 3. AI & Tiết kiệm Token (AI & Token Optimization)

#### 🎧 [Cài đặt Headroom Proxy](install_headroom.md) (`install_headroom.sh`)

Tự động cài đặt, cấu hình proxy và khởi chạy dịch vụ chạy ngầm Headroom giúp nén context cho Claude Code, giảm 60–95% chi phí token.

```sh
curl -fsSL https://raw.githubusercontent.com/trungnguyenthien/auto-script/refs/heads/main/install_headroom.sh -o install_headroom.sh && chmod +x install_headroom.sh && ./install_headroom.sh && rm install_headroom.sh
```

#### 🛡️ [Cài đặt RTK (Rust Token Killer)](install_rtk.md) (`install_rtk.sh`)

Cài đặt và thiết lập alias trong shell cho công cụ RTK, giúp AI Agent tự động tối ưu hóa logs và mã nguồn khi chạy git, npm, pytest,...

```sh
curl -fsSL https://raw.githubusercontent.com/trungnguyenthien/auto-script/refs/heads/main/install_rtk.sh -o install_rtk.sh && chmod +x install_rtk.sh && ./install_rtk.sh && rm install_rtk.sh
```

---

### 4. Tiện ích & Bảo mật (Utilities & Security)

#### 🔐 [Quét Bảo mật SQLite3](db_security_scanner.md) (`db_security_scanner.rb`)

Quét cấu trúc (schema) và toàn bộ dữ liệu của tệp cơ sở dữ liệu SQLite3 local ở chế độ chỉ đọc để phát hiện thông tin nhạy cảm (PII, API key, token, mật khẩu).

```sh
curl -fsSL https://raw.githubusercontent.com/trungnguyenthien/auto-script/refs/heads/main/db_security_scanner.rb -o db_security_scanner.rb && ruby db_security_scanner.rb <đường_dẫn_file_db> && rm db_security_scanner.rb
```

#### 🛡️ [Cài đặt Snyk CLI & Quét lỗ hổng](install_snyk_android.md) (`install_snyk_android.sh`)

Tự động kiểm tra và cài đặt Snyk CLI toàn cục, sau đó thực hiện quét thử lỗ hổng bảo mật của các thư viện phụ thuộc ngay tại thư mục hiện hành.

```sh
curl -fsSL https://raw.githubusercontent.com/trungnguyenthien/auto-script/refs/heads/main/install_snyk_android.sh -o install_snyk_android.sh && chmod +x install_snyk_android.sh && ./install_snyk_android.sh && rm install_snyk_android.sh
```

#### 🔑 [Xuất Chứng chỉ Keychain macOS](kc_export.md) (`kc_export.sh`)

Quét, liệt kê danh sách chứng chỉ từ login/system keychain trên macOS và hỗ trợ xuất nhanh chứng chỉ dưới định dạng `.p12` hoặc `.cer`.

```sh
curl -fsSL https://raw.githubusercontent.com/trungnguyenthien/auto-script/refs/heads/main/kc_export.sh -o kc_export.sh && chmod +x kc_export.sh && ./kc_export.sh && rm kc_export.sh
```

#### 📦 [Mã hóa Thư mục sang Base64](b64_dir.md) (`b64_dir.sh`)

Duyệt qua các tệp tin hợp lệ trong thư mục được chỉ định và tiến hành mã hóa nội dung của chúng thành định dạng Base64 (lưu dưới đuôi `.b64`).

```sh
curl -fsSL https://raw.githubusercontent.com/trungnguyenthien/auto-script/refs/heads/main/b64_dir.sh -o b64_dir.sh && chmod +x b64_dir.sh && ./b64_dir.sh <đường_dẫn_thư_mục> && rm b64_dir.sh
```

#### 📄 [Chuyển đổi Apple Property List (.plist)](convert_plist.md) (`convert_plist.rb`)

Nhận diện và tự động chuyển đổi tệp cấu hình `.plist` từ định dạng nhị phân (Binary) sang XML (Plain-text) bằng công cụ hệ thống `plutil`.

```sh
curl -fsSL https://raw.githubusercontent.com/trungnguyenthien/auto-script/refs/heads/main/convert_plist.rb -o convert_plist.rb && ruby convert_plist.rb <đường_dẫn_tệp_plist> && rm convert_plist.rb
```
