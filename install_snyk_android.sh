#!/bin/bash

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

# If not install Snyk then install snyk to global by "npm install -g snyk"
if ! command -v snyk &> /dev/null; then
  echo "❌ Snyk is not installed. Installing globally..."
  npm install -g snyk
else
  echo "✅ Snyk version: $(snyk -v)"
fi

# Thử nghiệm Snyk bằng cách chạy lệnh "snyk test"
snyk test