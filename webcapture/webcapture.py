#!/usr/bin/env python3
"""
webcapture - Full-page website screenshot tool
Takes screenshots of websites at specified widths with full scrollable content
"""

import sys
import os
import argparse
from pathlib import Path
from datetime import datetime
from urllib.parse import urlparse
import signal


class Colors:
    """ANSI color codes for terminal output"""
    RED = '\033[91m'
    GREEN = '\033[92m'
    YELLOW = '\033[93m'
    BLUE = '\033[94m'
    MAGENTA = '\033[95m'
    CYAN = '\033[96m'
    WHITE = '\033[97m'
    BOLD = '\033[1m'
    END = '\033[0m'


# Preset widths from browserprep
PRESETS = {
    'mobile': 375,
    'tablet': 768,
    'small': 1024,
    'laptop': 1440,
    'medium': 1366,
    'desktop': 1920,
    'large': 2560,
    'ultrawide': 3440,
    'presentation': 1280,
}

DEFAULT_WIDTH = 1920
DEFAULT_FORMAT = 'png'
DEFAULT_WAIT = 'networkidle'


def print_error(message):
    """Print error message in red"""
    print(f"{Colors.RED}✗ {message}{Colors.END}")


def print_success(message):
    """Print success message in green"""
    print(f"{Colors.GREEN}✓ {message}{Colors.END}")


def print_info(message):
    """Print info message in blue"""
    print(f"{Colors.BLUE}ℹ {message}{Colors.END}")


def print_warning(message):
    """Print warning message in yellow"""
    print(f"{Colors.YELLOW}⚠ {message}{Colors.END}")


def validate_url(url):
    """Validate URL format"""
    if not url.startswith(('http://', 'https://')):
        url = f'https://{url}'

    try:
        result = urlparse(url)
        if not all([result.scheme, result.netloc]):
            return None
        return url
    except Exception:
        return None


def sanitize_filename(url):
    """Create safe filename from URL"""
    parsed = urlparse(url)
    domain = parsed.netloc.replace('www.', '')
    domain = domain.replace('.', '-')
    return domain


def get_output_filename(url, width, output_format):
    """Generate output filename with timestamp"""
    base = sanitize_filename(url)
    timestamp = datetime.now().strftime('%Y-%m-%d_%H%M%S')
    desktop = Path.home() / 'Desktop'
    return desktop / f"{base}_{width}px_{timestamp}.{output_format}"


def capture_interactive_multiwidth(url, widths, output_format, dark_mode=False, wait_option='networkidle'):
    """Interactive mode with multiple widths - sign in once, capture all widths per Enter press"""
    try:
        from playwright.sync_api import sync_playwright
    except ImportError:
        print_error("Playwright not installed. Run: cd webcapture && ./install.sh")
        return False

    try:
        with sync_playwright() as p:
            # Launch visible browser
            browser = p.chromium.launch(headless=False)

            # Set color scheme
            color_scheme = 'dark' if dark_mode else 'light'

            # Create context with first width
            first_width = widths[0]
            context = browser.new_context(
                viewport={'width': first_width, 'height': 1080},
                color_scheme=color_scheme,
                device_scale_factor=1,
            )

            page = context.new_page()

            # Navigate with wait option
            if wait_option == 'networkidle':
                page.goto(url, wait_until='networkidle', timeout=60000)
            elif wait_option == 'load':
                page.goto(url, wait_until='load', timeout=60000)
            else:
                page.goto(url, wait_until='domcontentloaded', timeout=60000)
                page.wait_for_timeout(int(wait_option))

            print_info(f"Browser opened at {first_width}px width")
            print_warning(f"Navigate, sign in, or interact with page...")
            print_info(f"Will capture at {len(widths)} width(s) per Enter: {', '.join(str(w) for w in widths)}px")

            capture_round = 0
            total_captures = 0

            while True:
                try:
                    print(f"\n{Colors.CYAN}Press Enter to capture all widths (or type 'q' to finish):{Colors.END}")
                    user_input = input().strip().lower()

                    if user_input == 'q':
                        print_info("Finishing captures...")
                        break

                    # Get current URL for filename
                    current_url = page.url

                    # Capture at all widths
                    for width in widths:
                        # Resize viewport
                        page.set_viewport_size({'width': width, 'height': 1080})

                        # Generate filename using CURRENT URL
                        output_path = get_output_filename(current_url, width, output_format)
                        if capture_round > 0:
                            stem = output_path.stem
                            suffix = output_path.suffix
                            output_path = output_path.parent / f"{stem}_{capture_round}{suffix}"

                        # Capture screenshot (convert webp if needed)
                        if output_format == 'webp':
                            temp_png = output_path.with_suffix('.png')
                            page.screenshot(path=str(temp_png), full_page=True)
                            _convert_to_webp(temp_png, output_path)
                        else:
                            page.screenshot(path=str(output_path), full_page=True)

                        file_size = output_path.stat().st_size / 1024
                        print_success(f"Captured {width}px: {output_path.name} ({file_size:.1f} KB)")
                        total_captures += 1

                    capture_round += 1

                except KeyboardInterrupt:
                    print(f"\n{Colors.YELLOW}Interrupted by user{Colors.END}")
                    break

            # Cleanup
            context.close()
            browser.close()

            print(f"\n{Colors.GREEN}✓ Total captures: {total_captures}{Colors.END}")
            return total_captures > 0

    except Exception as e:
        print_error(f"Screenshot failed: {str(e)}")
        return False


def capture_screenshot(url, width, output_path, dark_mode=False, wait_option='networkidle', interactive=False):
    """Capture full-page screenshot using Playwright"""
    try:
        from playwright.sync_api import sync_playwright
    except ImportError:
        print_error("Playwright not installed. Run: cd webcapture && ./install.sh")
        return False

    try:
        with sync_playwright() as p:
            # Launch browser (headed if interactive)
            browser = p.chromium.launch(headless=not interactive)

            # Set color scheme
            color_scheme = 'dark' if dark_mode else 'light'

            # Create context with viewport
            context = browser.new_context(
                viewport={'width': width, 'height': 1080},
                color_scheme=color_scheme,
                device_scale_factor=1,
            )

            page = context.new_page()

            # Navigate with wait option
            if wait_option == 'networkidle':
                page.goto(url, wait_until='networkidle', timeout=60000)
            elif wait_option == 'load':
                page.goto(url, wait_until='load', timeout=60000)
            else:
                page.goto(url, wait_until='domcontentloaded', timeout=60000)
                page.wait_for_timeout(int(wait_option))

            # Interactive mode: continuous capture loop
            if interactive:
                print_info(f"Browser opened at {width}px width")
                print_warning("Navigate, sign in, or interact with page...")

                capture_count = 0
                while True:
                    try:
                        print(f"\n{Colors.CYAN}Press Enter to capture screenshot (or type 'q' to finish):{Colors.END}")
                        user_input = input().strip().lower()

                        if user_input == 'q':
                            print_info("Finishing captures...")
                            break

                        # Generate filename with counter for multiple captures
                        if capture_count == 0:
                            screenshot_path = output_path
                        else:
                            # Insert counter before extension
                            stem = output_path.stem
                            suffix = output_path.suffix
                            screenshot_path = output_path.parent / f"{stem}_{capture_count}{suffix}"

                        # Capture screenshot (convert webp if needed)
                        if screenshot_path.suffix.lower() == '.webp':
                            # Playwright doesn't support webp, capture as png then convert
                            temp_png = screenshot_path.with_suffix('.png')
                            page.screenshot(path=str(temp_png), full_page=True)
                            _convert_to_webp(temp_png, screenshot_path)
                        else:
                            page.screenshot(path=str(screenshot_path), full_page=True)

                        file_size = screenshot_path.stat().st_size / 1024
                        print_success(f"Captured: {screenshot_path.name} ({file_size:.1f} KB)")
                        capture_count += 1

                    except KeyboardInterrupt:
                        print(f"\n{Colors.YELLOW}Interrupted by user{Colors.END}")
                        break

                # Cleanup
                context.close()
                browser.close()

                return capture_count > 0

            else:
                # Non-interactive: single capture
                if output_path.suffix.lower() == '.webp':
                    # Playwright doesn't support webp, capture as png then convert
                    temp_png = output_path.with_suffix('.png')
                    page.screenshot(path=str(temp_png), full_page=True)
                    _convert_to_webp(temp_png, output_path)
                else:
                    page.screenshot(path=str(output_path), full_page=True)

                # Cleanup
                context.close()
                browser.close()

                return True

    except Exception as e:
        print_error(f"Screenshot failed: {str(e)}")
        return False


def _convert_to_webp(png_path, webp_path):
    """Convert PNG to WebP using ImageMagick"""
    import subprocess
    try:
        subprocess.run(
            ['convert', str(png_path), str(webp_path)],
            check=True,
            capture_output=True
        )
        # Remove temp PNG
        png_path.unlink()
    except FileNotFoundError:
        print_error("ImageMagick not found. Install with: brew install imagemagick")
        print_info(f"Keeping PNG file: {png_path.name}")
    except subprocess.CalledProcessError as e:
        print_error(f"WebP conversion failed: {e}")
        print_info(f"Keeping PNG file: {png_path.name}")


def print_menu(options, selected_idx):
    """Print menu with arrow navigation"""
    print("\033[2J\033[H")  # Clear screen
    print(f"{Colors.BOLD}{Colors.CYAN}=== webcapture - Full-Page Screenshots ==={Colors.END}\n")

    for idx, option in enumerate(options):
        prefix = "→" if idx == selected_idx else " "
        color = Colors.GREEN if idx == selected_idx else Colors.WHITE
        print(f"{color}{prefix} {option}{Colors.END}")


def get_key():
    """Get single keypress (arrow keys, enter)"""
    try:
        import termios
        import tty

        fd = sys.stdin.fileno()
        old_settings = termios.tcgetattr(fd)
        try:
            tty.setraw(fd)
            ch = sys.stdin.read(1)

            # Arrow keys send 3 bytes: ESC [ A/B
            if ch == '\x1b':
                ch += sys.stdin.read(2)
                if ch == '\x1b[A':
                    return 'up'
                elif ch == '\x1b[B':
                    return 'down'
            elif ch == '\r' or ch == '\n':
                return 'enter'
            elif ch == '\x03':  # Ctrl+C
                return 'quit'

            return ch
        finally:
            termios.tcsetattr(fd, termios.TCSADRAIN, old_settings)
    except:
        # Fallback for non-tty environments
        return input().strip()


def interactive_mode():
    """Run interactive menu"""
    # Main menu
    options = [
        "Single width (default: desktop 1920px)",
        "Multiple widths (mobile, tablet, desktop)",
        "Custom width(s)",
        "Advanced options",
        "Exit"
    ]

    selected = 0

    while True:
        print_menu(options, selected)
        key = get_key()

        if key == 'up':
            selected = (selected - 1) % len(options)
        elif key == 'down':
            selected = (selected + 1) % len(options)
        elif key == 'enter':
            if selected == 4:  # Exit
                print("\n")
                sys.exit(0)
            else:
                return handle_menu_selection(selected)
        elif key == 'quit':
            print("\n")
            sys.exit(0)


def handle_menu_selection(choice):
    """Handle interactive menu selection"""
    print("\033[2J\033[H")  # Clear

    # Get URL
    print(f"{Colors.CYAN}Enter URL:{Colors.END}")
    url_input = input("> ").strip()
    url = validate_url(url_input)

    if not url:
        print_error("Invalid URL")
        input("Press Enter to continue...")
        return False

    print_info(f"URL: {url}")

    # Get widths based on choice
    widths = []
    if choice == 0:  # Single default
        widths = [DEFAULT_WIDTH]
    elif choice == 1:  # Multiple preset
        widths = [375, 768, 1920]
    elif choice == 2:  # Custom
        print(f"{Colors.CYAN}Enter width(s) (comma-separated, e.g. 1920,375):{Colors.END}")
        custom = input("> ").strip()
        try:
            widths = [int(w.strip()) for w in custom.split(',')]
        except:
            print_error("Invalid width format")
            input("Press Enter to continue...")
            return False
    elif choice == 3:  # Advanced
        return advanced_options(url)

    # Get format
    print(f"{Colors.CYAN}Format (png/jpeg/webp) [default: png]:{Colors.END}")
    fmt = input("> ").strip().lower() or 'png'
    if fmt not in ['png', 'jpeg', 'webp']:
        fmt = 'png'

    # Get dark mode
    print(f"{Colors.CYAN}Dark mode? (y/n) [default: n]:{Colors.END}")
    dark = input("> ").strip().lower() == 'y'

    # Get interactive mode
    print(f"{Colors.CYAN}Interactive mode (open visible browser for sign in)? (y/n) [default: n]:{Colors.END}")
    interactive = input("> ").strip().lower() == 'y'

    # Execute captures
    print(f"\n{Colors.BOLD}Capturing screenshots...{Colors.END}\n")

    if interactive:
        # Interactive mode: single session, all widths per Enter
        capture_interactive_multiwidth(url, widths, fmt, dark, 'networkidle')
    else:
        # Non-interactive: capture each width separately
        success_count = 0
        for width in widths:
            output_path = get_output_filename(url, width, fmt)
            print_info(f"Capturing {width}px...")

            if capture_screenshot(url, width, output_path, dark, 'networkidle', False):
                file_size = output_path.stat().st_size / 1024
                print_success(f"Saved: {output_path.name} ({file_size:.1f} KB)")
                success_count += 1
            else:
                print_error(f"Failed: {width}px")

        print(f"\n{Colors.GREEN}✓ Completed: {success_count}/{len(widths)} screenshots{Colors.END}")

    input("\nPress Enter to continue...")
    return True


def advanced_options(url):
    """Handle advanced options"""
    print(f"{Colors.CYAN}Width presets:{Colors.END}")
    for name, width in sorted(PRESETS.items(), key=lambda x: x[1]):
        print(f"  {name}: {width}px")

    print(f"\n{Colors.CYAN}Enter preset names or widths (comma-separated):{Colors.END}")
    widths_input = input("> ").strip()

    widths = []
    for item in widths_input.split(','):
        item = item.strip().lower()
        if item in PRESETS:
            widths.append(PRESETS[item])
        else:
            try:
                widths.append(int(item))
            except:
                print_warning(f"Skipping invalid: {item}")

    if not widths:
        print_error("No valid widths")
        input("Press Enter to continue...")
        return False

    # Format
    print(f"\n{Colors.CYAN}Format (png/jpeg/webp) [default: png]:{Colors.END}")
    fmt = input("> ").strip().lower() or 'png'

    # Dark mode
    print(f"{Colors.CYAN}Dark mode? (y/n) [default: n]:{Colors.END}")
    dark = input("> ").strip().lower() == 'y'

    # Wait option
    print(f"{Colors.CYAN}Wait option (networkidle/load/ms) [default: networkidle]:{Colors.END}")
    wait = input("> ").strip().lower() or 'networkidle'

    # Get interactive mode
    print(f"{Colors.CYAN}Interactive mode (open visible browser for sign in)? (y/n) [default: n]:{Colors.END}")
    interactive = input("> ").strip().lower() == 'y'

    # Execute
    print(f"\n{Colors.BOLD}Capturing screenshots...{Colors.END}\n")

    if interactive:
        # Interactive mode: single session, all widths per Enter
        capture_interactive_multiwidth(url, widths, fmt, dark, wait)
    else:
        # Non-interactive: capture each width separately
        success_count = 0
        for width in widths:
            output_path = get_output_filename(url, width, fmt)
            print_info(f"Capturing {width}px...")

            if capture_screenshot(url, width, output_path, dark, wait, False):
                file_size = output_path.stat().st_size / 1024
                print_success(f"Saved: {output_path.name} ({file_size:.1f} KB)")
                success_count += 1
            else:
                print_error(f"Failed: {width}px")

        print(f"\n{Colors.GREEN}✓ Completed: {success_count}/{len(widths)} screenshots{Colors.END}")

    input("\nPress Enter to continue...")
    return True


def cli_mode(args):
    """Run CLI mode with arguments"""
    # Validate URL
    url = validate_url(args.url)
    if not url:
        print_error(f"Invalid URL: {args.url}")
        sys.exit(1)

    # Parse widths
    widths = []
    if args.widths:
        for item in args.widths.split(','):
            item = item.strip().lower()
            if item in PRESETS:
                widths.append(PRESETS[item])
            else:
                try:
                    widths.append(int(item))
                except:
                    print_warning(f"Skipping invalid width: {item}")

    if not widths:
        widths = [DEFAULT_WIDTH]

    # Validate format
    output_format = args.format.lower()
    if output_format not in ['png', 'jpeg', 'webp']:
        print_warning(f"Invalid format: {args.format}, using png")
        output_format = 'png'

    # Execute captures
    print(f"{Colors.BOLD}Capturing: {url}{Colors.END}")
    print(f"Widths: {', '.join(str(w) for w in widths)}")
    print(f"Format: {output_format}")
    print(f"Dark mode: {args.dark}")
    print(f"Wait: {args.wait}")
    print(f"Interactive: {args.interactive}\n")

    if args.interactive:
        # Interactive mode: single browser session, capture all widths per Enter
        capture_interactive_multiwidth(url, widths, output_format, args.dark, args.wait)
    else:
        # Non-interactive: capture each width separately
        success_count = 0
        for width in widths:
            output_path = get_output_filename(url, width, output_format)
            print_info(f"Capturing {width}px...")
            if capture_screenshot(url, width, output_path, args.dark, args.wait, False):
                file_size = output_path.stat().st_size / 1024
                print_success(f"Saved: {output_path.name} ({file_size:.1f} KB)")
                success_count += 1
            else:
                print_error(f"Failed: {width}px")

        print(f"\n{Colors.GREEN}✓ Completed: {success_count}/{len(widths)} screenshots{Colors.END}")


def signal_handler(sig, frame):
    """Handle Ctrl+C gracefully"""
    print(f"\n\n{Colors.YELLOW}Cancelled by user{Colors.END}")
    sys.exit(0)


def main():
    """Main entry point"""
    signal.signal(signal.SIGINT, signal_handler)

    parser = argparse.ArgumentParser(
        description='webcapture - Full-page website screenshots',
        epilog='''Examples:
  webcapture https://example.com
  webcapture --widths 375,1920 --dark https://example.com
  webcapture --widths mobile,desktop,ultrawide --format webp https://example.com
  webcapture --wait 3000 https://example.com
  webcapture -i https://app.example.com  # Interactive: sign in once, capture multiple times
  webcapture -i --widths mobile,desktop https://app.example.com  # Sign in once, all widths per Enter

Preset widths: mobile(375), tablet(768), small(1024), laptop(1440),
medium(1366), desktop(1920), large(2560), ultrawide(3440), presentation(1280)
        ''',
        formatter_class=argparse.RawDescriptionHelpFormatter
    )

    parser.add_argument('url', nargs='?', help='Website URL to capture')
    parser.add_argument('--widths', '-w', help='Comma-separated widths or presets (default: 1920)')
    parser.add_argument('--format', '-f', default='png', help='Output format: png, jpeg, webp (default: png)')
    parser.add_argument('--dark', '-d', action='store_true', help='Enable dark mode')
    parser.add_argument('--wait', default='networkidle', help='Wait option: networkidle, load, or ms (default: networkidle)')
    parser.add_argument('--interactive', '-i', action='store_true', help='Open visible browser, wait for manual interaction (e.g., sign in)')

    args = parser.parse_args()

    # Interactive mode if no URL provided
    if not args.url:
        try:
            while True:
                interactive_mode()
        except KeyboardInterrupt:
            print(f"\n\n{Colors.YELLOW}Cancelled{Colors.END}")
            sys.exit(0)
    else:
        cli_mode(args)


if __name__ == '__main__':
    main()
