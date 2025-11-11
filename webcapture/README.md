# webcapture

Full-page website screenshot tool using Playwright.

## Features

- **Full-page screenshots** - Captures entire scrollable content
- **Multiple widths** - Desktop, mobile, tablet, and custom sizes
- **Dark mode** - Toggle light/dark theme
- **Format options** - PNG, JPEG, WebP
- **JS wait** - networkidle, load, or custom timeout
- **Interactive mode** - Opens visible browser for manual sign in/interaction
- **Interactive & CLI modes** - Menu-driven or direct command

## Installation

```bash
cd webcapture
./install.sh
```

This creates a virtual environment and installs Playwright + Chromium.

## Usage

### Register tool (optional)
```bash
cd /Users/fdiazsmith/env_tools
./register-tool.sh webcapture/webcapture
```

### CLI Mode

```bash
# Default (desktop 1920px, PNG)
./webcapture https://example.com

# Multiple widths
./webcapture --widths 375,1920,3440 https://example.com

# Preset widths
./webcapture --widths mobile,desktop,ultrawide https://example.com

# Dark mode + WebP
./webcapture --dark --format webp https://example.com

# Custom JS wait (3 seconds)
./webcapture --wait 3000 https://example.com

# Interactive mode (visible browser, wait for sign in)
./webcapture --interactive https://app.example.com
./webcapture -i --widths mobile,desktop https://app.example.com
```

### Interactive Menu Mode

```bash
./webcapture
```

Use arrow keys to navigate menu.

## Interactive Mode

For sites requiring authentication or multiple captures:

1. Use `--interactive` or `-i` flag
2. Browser opens visibly
3. Navigate, sign in, or interact with page
4. Press Enter to capture screenshot(s)
5. **Browser stays open** - navigate to new page/state
6. Press Enter again for another screenshot
7. Type 'q' + Enter to finish and close browser

**Features:**
- Sign in once, capture multiple times without re-authenticating
- Navigate between pages/states
- **Multiple widths captured per Enter press** - no need to sign in for each width!
- Auto-numbered files: `name.png`, `name_1.png`, `name_2.png`...
- Perfect for authenticated content, flows, or comparisons

**Example with multiple widths:**
```bash
webcapture -i --widths mobile,desktop,ultrawide https://app.example.com
```

**What happens:**
1. Browser opens at 375px (mobile width)
2. Sign in once
3. Press Enter → captures at 375px, 1920px, 3440px (viewport auto-resizes)
4. Navigate to another page
5. Press Enter → captures all 3 widths again
6. Type 'q' → done!

**Files created (filenames match current page URL):**
```
app-example-com_375px_timestamp.png
app-example-com_1920px_timestamp.png
app-example-com_3440px_timestamp.png
app-example-com-dashboard_375px_timestamp.png      # After navigating to /dashboard
app-example-com-dashboard_1920px_timestamp.png
app-example-com-dashboard_3440px_timestamp.png
```

**Note:** Filenames are generated from the current URL when you press Enter, so each page gets unique names.

## Width Presets

- mobile: 375px
- tablet: 768px
- small: 1024px
- laptop: 1440px
- medium: 1366px
- desktop: 1920px (default)
- large: 2560px
- ultrawide: 3440px
- presentation: 1280px

## Output

Files saved to `~/Desktop` with format:
```
example-com_1920px_2025-11-11_143052.png
```

## Dependencies

- Python 3
- Playwright (isolated in `venv/`)
- Chromium (auto-downloaded)
- ImageMagick (for WebP conversion) - `brew install imagemagick`

**Note:** WebP screenshots are captured as PNG first, then converted using ImageMagick.
