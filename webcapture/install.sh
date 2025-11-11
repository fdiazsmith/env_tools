#!/usr/bin/env bash
# webcapture installation script
# Sets up isolated venv and installs Playwright

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="$SCRIPT_DIR/venv"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== webcapture Installation ===${NC}\n"

# Check Python 3
if ! command -v python3 &> /dev/null; then
    echo -e "${RED}✗ Python 3 not found${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Python 3 found${NC}"

# Create venv
if [ -d "$VENV_DIR" ]; then
    echo -e "${YELLOW}⚠ venv exists, removing...${NC}"
    rm -rf "$VENV_DIR"
fi

echo -e "${BLUE}Creating virtual environment...${NC}"
python3 -m venv "$VENV_DIR"
echo -e "${GREEN}✓ venv created${NC}"

# Activate and install
echo -e "${BLUE}Installing dependencies...${NC}"
source "$VENV_DIR/bin/activate"
pip install --upgrade pip > /dev/null 2>&1
pip install -r "$SCRIPT_DIR/requirements.txt"
echo -e "${GREEN}✓ Dependencies installed${NC}"

# Install Playwright browsers
echo -e "${BLUE}Installing Playwright browsers...${NC}"
playwright install chromium
echo -e "${GREEN}✓ Chromium installed${NC}"

echo -e "\n${GREEN}✓ Installation complete!${NC}"
echo -e "${BLUE}Run: ${NC}./webcapture --help"
