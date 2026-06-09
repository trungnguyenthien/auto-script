#!/bin/bash

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== Ruby Installation Script via rbenv for macOS ===${NC}\n"

# Check if Homebrew is installed
echo -e "${BLUE}Checking Homebrew...${NC}"
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

# Install rbenv and ruby-build
echo -e "\n${BLUE}Installing/Updating rbenv and ruby-build...${NC}"
brew install rbenv ruby-build

# Detect shell
if [ -n "$ZSH_VERSION" ]; then
    SHELL_RC="$HOME/.zshrc"
elif [ -n "$BASH_VERSION" ]; then
    SHELL_RC="$HOME/.bash_profile"
else
    SHELL_RC="$HOME/.zshrc"
fi

# Configure rbenv in shell RC
echo -e "\n${BLUE}Configuring rbenv shell integration in $SHELL_RC...${NC}"
# Use a robust check to avoid duplicated lines
if ! grep -q 'rbenv init' "$SHELL_RC" 2>/dev/null; then
    echo "" >> "$SHELL_RC"
    echo "# rbenv configuration" >> "$SHELL_RC"
    echo 'eval "$(rbenv init -)"' >> "$SHELL_RC"
    echo -e "${GREEN}✓ rbenv init script added to $SHELL_RC${NC}"
else
    echo -e "${YELLOW}rbenv init script already exists in $SHELL_RC${NC}"
fi

# Initialize rbenv for current script execution context
export PATH="$HOME/.rbenv/shims:$HOME/.rbenv/bin:$PATH"
eval "$(rbenv init -)"

# Finding the latest stable Ruby version
echo -e "\n${BLUE}Finding the latest stable Ruby version from rbenv...${NC}"
LATEST_STABLE=$(rbenv install -l 2>/dev/null | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' | tail -n 1)

if [ -z "$LATEST_STABLE" ]; then
    # Fallback stable version if dynamic query fails
    LATEST_STABLE="3.3.3"
    echo -e "${YELLOW}Could not dynamically determine latest version, falling back to: $LATEST_STABLE${NC}"
else
    echo -e "${GREEN}✓ Latest stable Ruby version found: $LATEST_STABLE${NC}"
fi

echo -e "${YELLOW}Do you want to install version $LATEST_STABLE? (yes/no/custom):${NC}"
read -r CHOICE

if [[ "$CHOICE" == "custom" || "$CHOICE" == "c" ]]; then
    echo -e "${YELLOW}Enter the version you want to install (e.g. 3.2.2):${NC}"
    read -r SELECTED_VERSION
elif [[ "$CHOICE" == "no" || "$CHOICE" == "n" ]]; then
    echo -e "${BLUE}Installation cancelled.${NC}"
    exit 0
else
    SELECTED_VERSION=$LATEST_STABLE
fi

# Check if selected version is already installed
if rbenv versions --bare | grep -q "^${SELECTED_VERSION}$"; then
    echo -e "${GREEN}✓ Ruby $SELECTED_VERSION is already installed via rbenv.${NC}"
else
    echo -e "\n${BLUE}Installing Ruby $SELECTED_VERSION... (This may take a few minutes as it compiles from source)${NC}"
    rbenv install "$SELECTED_VERSION"
fi

# Set version as global
echo -e "\n${BLUE}Setting Ruby $SELECTED_VERSION as global...${NC}"
rbenv global "$SELECTED_VERSION"
rbenv rehash

# Verify installation
echo -e "\n${BLUE}Verifying Ruby installation...${NC}"
CURRENT_RUBY=$(ruby --version)
CURRENT_RUBY_PATH=$(which ruby)

if [[ "$CURRENT_RUBY_PATH" == *".rbenv/shims/ruby"* ]]; then
    echo -e "${GREEN}✓ Ruby installed successfully via rbenv!${NC}"
    echo -e "${GREEN}  Version: ${CURRENT_RUBY}${NC}"
    echo -e "${GREEN}  Path: ${CURRENT_RUBY_PATH}${NC}"
else
    echo -e "${RED}✗ Warning: The current ruby path is ${CURRENT_RUBY_PATH}.${NC}"
    echo -e "${YELLOW}It seems your terminal has not loaded the rbenv shims yet.${NC}"
    echo -e "${YELLOW}We will try to explicitly run ruby from rbenv shims for verification...${NC}"
    
    SHIM_RUBY="$HOME/.rbenv/shims/ruby"
    if [ -f "$SHIM_RUBY" ]; then
        echo -e "${GREEN}✓ Ruby is present at: $SHIM_RUBY${NC}"
        echo -e "${GREEN}  Version: $($SHIM_RUBY --version)${NC}"
    else
        echo -e "${RED}✗ Verification failed. Ruby is not found in rbenv shims.${NC}"
        exit 1
    fi
fi

# Install Bundler
echo -e "\n${BLUE}Installing Bundler...${NC}"
gem install bundler --no-document
rbenv rehash

echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}✓ Installation completed successfully!${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "\n${YELLOW}⚠️  IMPORTANT: Please run the following command to apply changes in your current session:${NC}"
echo -e "${BLUE}source $SHELL_RC${NC}"
echo -e "\n${YELLOW}Or simply restart your terminal.${NC}"
echo -e "\n${BLUE}After that, verify Ruby is managed by rbenv:${NC}"
echo -e "${BLUE}which ruby${NC} (Should return: $HOME/.rbenv/shims/ruby)"