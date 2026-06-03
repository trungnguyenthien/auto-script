#!/bin/bash

# Thiết lập màu sắc hiển thị cho terminal
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

clear
echo -e "${BLUE}================================================================${NC}"
echo -e "${GREEN}    BỘ CÀI ĐẶT TỰ ĐỘNG CÔNG CỤ RTK (RUST TOKEN KILLER)          ${NC}"
echo -e "${BLUE}================================================================${NC}"
echo ""

# 1. Giải thích chức năng công cụ
echo -e "${YELLOW}[GIỚI THIỆU VỀ RTK]:${NC}"
echo -e "RTK là một công cụ dòng lệnh (CLI proxy) viết bằng Rust, đóng vai trò trung gian"
echo -e "giữa Terminal của bạn và các AI Agent (như Claude Code, Cursor, Copilot...)."
echo ""
echo -e "${GREEN}Chức năng cốt lõi:${NC}"
echo -e " * ${GREEN}Tiết kiệm 60% - 90% Token đầu vào (Input Context)${NC} gửi lên các mô hình LLM."
echo -e " * Tự động lọc bỏ log rác, khoảng trắng, các dòng test thành công dư thừa."
echo -e " * Chỉ giữ lại log lỗi cốt lõi, cấu trúc thư mục rút gọn để AI đọc nhanh hơn."
echo -e " * Giảm đáng kể chi phí sử dụng API và giúp AI sinh code chuẩn xác hơn."
echo ""
echo -e "${BLUE}----------------------------------------------------------------${NC}"

# 2. Hỏi ý kiến người dùng
read -p "Bạn có muốn tiến hành cài đặt RTK tự động không? (y/n): " choice

case "$choice" in 
  y|Y ) 
    echo -e "\n${BLUE}[1/3] Bắt đầu quá trình cài đặt...${NC}"
    ;;
  * )
    echo -e "\n${RED}Đã hủy bỏ cài đặt. Hẹn gặp lại bạn lần sau!${NC}\n"
    exit 0
    ;;
esac

# 3. Chạy lệnh cài đặt chính thức từ rtk.ai
if curl -fsSL https://rtk.ai/install.sh | sh; then
    echo -e "${GREEN}✓ Tải và cài đặt file thực thi RTK thành công!${NC}"
else
    echo -e "${RED}✗ Thất bại trong quá trình tải RTK. Vui lòng kiểm tra lại kết nối mạng.${NC}"
    exit 1
fi

echo -e "\n${BLUE}[2/3] Đang kiểm tra cấu hình Shell để thiết lập Alias tự động...${NC}"

# 4. Xác định file cấu hình Shell của người dùng
SHELL_RC=""
if [[ "$SHELL" == */zsh ]]; then
    SHELL_RC="$HOME/.zshrc"
elif [[ "$SHELL" == */bash ]]; then
    SHELL_RC="$HOME/.bashrc"
else
    SHELL_RC="$HOME/.profile"
fi

echo -e "Phát hiện Shell hiện tại của bạn sử dụng file cấu hình: ${YELLOW}$SHELL_RC${NC}"

# 5. Thêm cấu hình Alias tối ưu cho AI Agent nếu chưa tồn tại
alias_block="
# --- RTK CONFIGURATION FOR AI AGENTS ---
if command -v rtk &> /dev/null; then
    alias git='rtk git'
    alias npm='rtk npm'
    alias cargo='rtk cargo'
    alias pytest='rtk pytest'
fi
# --------------------------------------"

if grep -q "RTK CONFIGURATION FOR AI AGENTS" "$SHELL_RC"; then
    echo -e "${YELLOW}! Các cấu hình Alias cho RTK đã tồn tại sẵn trong $SHELL_RC.${NC}"
else
    echo "$alias_block" >> "$SHELL_RC"
    echo -e "${GREEN}✓ Đã tự động thêm các Alias tối ưu (git, npm, cargo, pytest) vào $SHELL_RC!${NC}"
fi

# 6. Hoàn tất
echo -e "\n${BLUE}[3/3] Hoàn tất cài đặt!${NC}"
echo -e "${GREEN}================================================================${NC}"
echo -e "${GREEN}Chúc mừng! RTK đã sẵn sàng hoạt động.${NC}"
echo -e "Để áp dụng các thay đổi ngay lập tức cho Terminal hiện tại, hãy chạy lệnh:"
echo -e "${YELLOW}source $SHELL_RC${NC}"
echo -e "Hoặc đơn giản là tắt Terminal này đi và mở một cửa sổ mới."
echo -e "${GREEN}================================================================${NC}\n"