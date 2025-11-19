#!/bin/bash

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== Ruby Installation Script for macOS ===${NC}\n"

# Check if Ruby is already installed
if command -v ruby &> /dev/null; then
    RUBY_VERSION=$(ruby --version)
    echo -e "${GREEN}✓ Ruby is already installed: ${RUBY_VERSION}${NC}"
    echo -e "${YELLOW}Do you want to install/upgrade to the latest version? (yes/no):${NC}"
    read -r UPGRADE
    
    if [ "$UPGRADE" != "yes" ]; then
        echo -e "${BLUE}Installation cancelled.${NC}"
        exit 0
    fi
fi

# Check if Homebrew is installed
echo -e "\n${BLUE}Checking Homebrew...${NC}"
if ! command -v brew &> /dev/null; then
    echo -e "${YELLOW}Homebrew is not installed. Installing Homebrew...${NC}"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    
    # Add Homebrew to PATH based on architecture
    if [[ $(uname -m) == 'arm64' ]]; then
        # Apple Silicon
        echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
        eval "$(/opt/homebrew/bin/brew shellenv)"
    else
        # Intel
        echo 'eval "$(/usr/local/bin/brew shellenv)"' >> ~/.zprofile
        eval "$(/usr/local/bin/brew shellenv)"
    fi
    
    echo -e "${GREEN}✓ Homebrew installed successfully!${NC}"
else
    echo -e "${GREEN}✓ Homebrew is already installed${NC}"
fi

# Update Homebrew
echo -e "\n${BLUE}Updating Homebrew...${NC}"
brew update

# Install Ruby
echo -e "\n${BLUE}Installing Ruby...${NC}"
brew install ruby

# Detect shell
if [ -n "$ZSH_VERSION" ]; then
    SHELL_RC="$HOME/.zshrc"
elif [ -n "$BASH_VERSION" ]; then
    SHELL_RC="$HOME/.bash_profile"
else
    SHELL_RC="$HOME/.zshrc"
fi

# Add Ruby to PATH
echo -e "\n${BLUE}Configuring Ruby PATH...${NC}"

# Check architecture and set appropriate path
if [[ $(uname -m) == 'arm64' ]]; then
    RUBY_PATH="/opt/homebrew/opt/ruby/bin"
else
    RUBY_PATH="/usr/local/opt/ruby/bin"
fi

# Check if PATH already contains Ruby
if ! grep -q "$RUBY_PATH" "$SHELL_RC" 2>/dev/null; then
    echo "" >> "$SHELL_RC"
    echo "# Ruby configuration" >> "$SHELL_RC"
    echo "export PATH=\"$RUBY_PATH:\$PATH\"" >> "$SHELL_RC"
    echo -e "${GREEN}✓ Ruby PATH added to $SHELL_RC${NC}"
else
    echo -e "${YELLOW}Ruby PATH already exists in $SHELL_RC${NC}"
fi

# Source the shell configuration
source "$SHELL_RC" 2>/dev/null || true

# Verify installation
echo -e "\n${BLUE}Verifying Ruby installation...${NC}"
export PATH="$RUBY_PATH:$PATH"

if command -v ruby &> /dev/null; then
    RUBY_VERSION=$(ruby --version)
    RUBY_LOCATION=$(which ruby)
    
    echo -e "${GREEN}✓ Ruby installed successfully!${NC}"
    echo -e "${GREEN}  Version: ${RUBY_VERSION}${NC}"
    echo -e "${GREEN}  Location: ${RUBY_LOCATION}${NC}"
else
    echo -e "${RED}✗ Ruby installation verification failed${NC}"
    echo -e "${YELLOW}Please restart your terminal and try running: ruby --version${NC}"
    exit 1
fi

# Install bundler (useful for Ruby projects)
echo -e "\n${BLUE}Installing Bundler...${NC}"
gem install bundler --no-document

echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}✓ Installation completed successfully!${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "\n${YELLOW}⚠️  IMPORTANT: Please run the following command to apply changes:${NC}"
echo -e "${BLUE}source $SHELL_RC${NC}"
echo -e "\n${YELLOW}Or simply restart your terminal.${NC}"
echo -e "\n${BLUE}After that, verify Ruby is working:${NC}"
echo -e "${BLUE}ruby --version${NC}"