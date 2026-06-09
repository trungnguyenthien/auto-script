#!/bin/bash

# ==============================
# COMMITLINT + HUSKY SETUP SCRIPT
# ==============================
#
# TỔNG QUAN CHỨC NĂNG:
# Script này tự động cài đặt và cấu hình Commitlint + Husky cho dự án Git
# - Commitlint: Kiểm tra format commit message theo chuẩn Conventional Commits
# - Husky: Quản lý Git hooks để chạy các tác vụ tự động khi commit/push
# - Tạo các Git hooks cơ bản: commit-msg, pre-commit, pre-push, post-commit, prepare-commit-msg
#
# CÁC BƯỚC CHẠY SCRIPT:
# 1. Kiểm tra và cài đặt dependencies (Homebrew, Node.js, npm)
# 2. Tạo package.json tự động nếu chưa có (dành cho dự án Android)
# 3. Kiểm tra và bổ sung prepare script vào package.json hiện có
# 3. Cài đặt Commitlint@19.8.1 và Husky@9.1.7 globally
# 4. Tạo file cấu hình commitlint.config.cjs
# 4. Khởi tạo Husky và tạo thư mục .husky/
# 5. Tạo các Git hooks cần thiết với template cơ bản
#
# CÁCH SỬ DỤNG:
# chmod +x install_commitlint_husky.sh && ./install_commitlint_husky.sh
# HOẶC:
# curl -fsSL https://raw.githubusercontent.com/trungnguyenthien/auto-script/refs/heads/main/install_commitlint_husky.sh -o install_commitlint_husky.sh && chmod +x install_commitlint_husky.sh && ./install_commitlint_husky.sh && rm install_commitlint_husky.sh
#
# TEST KẾT QUẢ THỰC HIỆN:
# 1. Kiểm tra cài đặt:
#    - commitlint --version (should show 19.8.1)
#    - husky --version (should show 9.1.7)
#    - ls -la .husky/ (should show all hook files)
#
# 2. Test commit message validation:
#    - git add .
#    - git commit -m "invalid message" (should fail)
#    - git commit -m "feat: add new feature" (should pass)
#
# 3. Test hooks execution:
#    - Các hooks sẽ chạy tự động khi: commit, push, etc.
#    - Check git log để xem hooks có được trigger không
#
# YÊU CẦU HỆ THỐNG:
# - macOS với Homebrew
# - Git repository đã được khởi tạo (git init)
# - Quyền sudo để cài đặt global packages
#
# ==============================

# 1. Check Homebrew
if ! command -v brew &> /dev/null; then
  echo "❌ Homebrew is not installed."
  echo "👉 Install it with:"
  echo '/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
  exit 1
else
  echo "✅ Homebrew is installed."
fi

# 2. Check Node.js
if ! command -v node &> /dev/null; then
  echo "❌ Node.js is not installed. Installing with Homebrew..."
  brew install node
else
  echo "✅ Node.js version: $(node -v)"
fi

# 3. Check npm
if ! command -v npm &> /dev/null; then
  echo "❌ npm is not installed. Please verify your Node.js installation."
  exit 1
else
  echo "✅ npm version: $(npm -v)"
fi

# 4. Install commitlint globally (specific version)
if ! command -v commitlint &> /dev/null; then
  echo "📦 Installing commitlint@19.8.1 globally..."
  sudo npm install -g @commitlint/cli@19.8.1 @commitlint/config-conventional@19.8.1
else
  echo "✅ commitlint is already installed"
fi

# 5. Install husky globally (specific version)
if ! command -v husky &> /dev/null; then
  echo "📦 Installing husky@9.1.7 globally..."
  sudo npm install -g husky@9.1.7
else
  echo "✅ husky is already installed"
fi

# 6. Setup commitlint config in the project (use .cjs to avoid ESM issues)
if [ ! -f commitlint.config.cjs ]; then
  echo "📄 Creating commitlint.config.cjs..."
  cat <<EOF > commitlint.config.cjs
module.exports = {
  extends: ['@commitlint/config-conventional'],
  rules: {
    'header-max-length': [2, 'always', 300],
    'body-max-line-length': [2, 'always', 300],
    'footer-max-line-length': [2, 'always', 300]
  }
};
EOF
else
  echo "✅ commitlint.config.cjs already exists, skipping."
fi

# 7. Check and create package.json if not exists (required for husky)
if [ ! -f package.json ]; then
  # Get current directory name for project name
  PROJECT_NAME=$(basename "$(pwd)")
  echo "📄 Creating package.json for project: $PROJECT_NAME..."
  cat <<EOF > package.json
{
  "name": "$PROJECT_NAME",
  "version": "1.0.0",
  "description": "Project with commitlint and husky setup",
  "main": "index.js",
  "scripts": {
    "test": "echo \"Error: no test specified\" && exit 1",
    "prepare": "husky"
  },
  "repository": {
    "type": "git",
    "url": "."
  },
  "keywords": ["commitlint", "husky"],
  "author": "",
  "license": "MIT",
  "devDependencies": {},
  "type": "commonjs"
}
EOF
  echo "✅ package.json created for project: $PROJECT_NAME."
else
  echo "✅ package.json already exists."

  # Check if prepare script exists, add if missing
  if ! grep -q '"prepare"' package.json; then
    echo "📝 Adding prepare script to package.json..."
    # Use node to safely add the prepare script
    node -e "
      const fs = require('fs');
      const pkg = JSON.parse(fs.readFileSync('package.json', 'utf8'));
      if (!pkg.scripts) pkg.scripts = {};
      pkg.scripts.prepare = 'husky';
      fs.writeFileSync('package.json', JSON.stringify(pkg, null, 2));
    "
    echo "✅ prepare script added to package.json."
  fi
fi

# 8. Create .husky directory if not exists
if [ ! -d .husky ]; then
  echo "🚀 Initializing husky in the project..."
  npx husky init
  echo "📂 Creating .husky directory..."
  mkdir -p .husky
else
  echo "✅ .husky/ directory already exists."
fi

# Ensure .husky directory is executable
echo "🔧 Making .husky directory executable..."
chmod +x .husky

# 9. Add commit-msg hook (commitlint runs here)
if [ ! -f .husky/commit-msg ]; then
  echo "🪝 Creating husky commit-msg hook..."
  cat > .husky/commit-msg << 'EOF'
#!/bin/sh
npx --no-install commitlint --edit "$1"
EOF
else
  echo "✅ .husky/commit-msg already exists, skipping."
fi

# Ensure commit-msg hook is executable
echo "🔧 Making .husky/commit-msg executable..."
chmod +x .husky/commit-msg

# 10. Add or update pre-commit hook
if [ ! -f .husky/pre-commit ]; then
  echo "🪝 Creating husky pre-commit hook..."
  cat > .husky/pre-commit << 'EOF'
#!/bin/sh
# This hook runs before creating a commit (commonly used for lint/test).
EOF
else
  # Check if the file only contains 'npm test'
  if grep -q "npm test" .husky/pre-commit && [ $(wc -l < .husky/pre-commit) -le 3 ]; then
    echo "♻️ Updating default husky pre-commit (npm test) to template..."
    cat > .husky/pre-commit << 'EOF'
#!/bin/sh
# This hook runs before creating a commit (commonly used for lint/test).
EOF
  else
    echo "✅ .husky/pre-commit already exists, skipping."
  fi
fi

# Ensure pre-commit hook is executable
echo "🔧 Making .husky/pre-commit executable..."
chmod +x .husky/pre-commit

# 11. Add prepare-commit-msg hook
if [ ! -f .husky/prepare-commit-msg ]; then
  cat > .husky/prepare-commit-msg << 'EOF'
#!/bin/sh
# This hook runs before the commit message editor is fired.
# It can be used to modify the commit message before user edits it.
EOF
else
  echo "✅ .husky/prepare-commit-msg already exists, skipping."
fi

# Ensure prepare-commit-msg hook is executable
echo "🔧 Making .husky/prepare-commit-msg executable..."
chmod +x .husky/prepare-commit-msg

# 12. Add post-commit hook
if [ ! -f .husky/post-commit ]; then
  cat > .husky/post-commit << 'EOF'
#!/bin/sh
# This hook runs after a commit is created.
EOF
else
  echo "✅ .husky/post-commit already exists, skipping."
fi

# Ensure post-commit hook is executable
echo "🔧 Making .husky/post-commit executable..."
chmod +x .husky/post-commit

# 13. Add pre-push hook
if [ ! -f .husky/pre-push ]; then
  echo "🪝 Creating husky pre-push hook..."
  cat > .husky/pre-push << 'EOF'
#!/bin/sh
# This hook runs before pushing commits to remote.
# Commonly used for running tests, lint, or build verification.
EOF
else
  echo "✅ .husky/pre-push already exists, skipping."
fi

# Ensure pre-push hook is executable
echo "🔧 Making .husky/pre-push executable..."
chmod +x .husky/pre-push

echo "🎉 Commitlint (19.8.1) + Husky (9.1.7) setup complete with multiple hooks created!"
