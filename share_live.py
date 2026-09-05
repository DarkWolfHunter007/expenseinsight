import os
import re
import sys
import time
import subprocess
import shutil

# Ensure UTF-8 console output for beautiful ASCII QR rendering
if sys.platform == 'win32':
    try:
        sys.stdout.reconfigure(encoding='utf-8')
    except Exception:
        pass

try:
    import qrcode
except ImportError:
    print('[!] Installing required qrcode library...')
    subprocess.check_call([sys.executable, '-m', 'pip', 'install', 'qrcode[pil]'])
    import qrcode

CYAN = '\033[1;36m'
GREEN = '\033[1;32m'
YELLOW = '\033[1;33m'
BLUE = '\033[1;34m'
MAGENTA = '\033[1;35m'
BOLD = '\033[1m'
RESET = '\033[0m'

def print_banner():
    print(f'''
{CYAN}======================================================================{RESET}
{BOLD}{CYAN}🚀 ExpenseInsight — Live Cloudflare Tunnel & Mobile QR Code Share{RESET}
{CYAN}======================================================================{RESET}
''')

def check_cloudflared():
    path = shutil.which('cloudflared')
    if not path:
        # Check standard default Windows winget install locations
        win_path = os.path.expanduser('~\\AppData\\Local\\Microsoft\\WinGet\\Packages\\Cloudflare.cloudflared_Microsoft.Winget.Source_8wekyb3d8bbwe\\cloudflared.exe')
        if os.path.exists(win_path):
            return win_path
        prog_path = 'C:\\Program Files (x86)\\cloudflared\\cloudflared.exe'
        if os.path.exists(prog_path):
            return prog_path
    return path

def print_qr(url: str):
    qr = qrcode.QRCode(
        version=1,
        error_correction=qrcode.constants.ERROR_CORRECT_L,
        box_size=1,
        border=2,
    )
    qr.add_data(url)
    qr.make(fit=True)
    
    print(f'\n{GREEN}{BOLD}📱 SCAN WITH YOUR PHONE CAMERA TO OPEN INSTANTLY:{RESET}\n')
    qr.print_ascii(invert=True)
    print(f'\n{YELLOW}{BOLD}🌐 Public Live URL:{RESET} {CYAN}{BOLD}{url}{RESET}')
    print(f'{MAGENTA}💻 Local Access:{RESET}    http://localhost:3000 (Frontend) | http://localhost:8000 (Backend API)\n')

def main():
    print_banner()

    # 1. Target Port resolution (prefer port 80/3000 for frontend, or 8000 for backend)
    target_port = 80
    if len(sys.argv) > 1:
        try:
            target_port = int(sys.argv[1])
        except ValueError:
            target_port = 80

    # 2. Check cloudflared binary
    cloudflared_bin = check_cloudflared()
    if not cloudflared_bin:
        print(f'{YELLOW}[!] Cloudflare Tunnel CLI (cloudflared) is not detected.{RESET}')
        print(f'{GREEN}To install in 10 seconds via PowerShell, run:{RESET}')
        print(f'   {BOLD}winget install Cloudflare.cloudflared{RESET}\n')
        print(f'Or download from: https://github.com/cloudflare/cloudflared/releases\n')
        return

    print(f'{BLUE}[1/2] Connecting Cloudflare Tunnel to port {target_port}...{RESET}')
    
    cmd = [cloudflared_bin, 'tunnel', '--url', f'http://localhost:{target_port}']
    
    try:
        process = subprocess.Popen(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            encoding='utf-8',
            errors='replace'
        )

        public_url = None
        start_time = time.time()

        while time.time() - start_time < 25:
            line = process.stdout.readline()
            if not line and process.poll() is not None:
                break
            
            # Search for https://*.trycloudflare.com
            match = re.search(r'(https://[a-zA-Z0-9\-]+\.trycloudflare\.com)', line)
            if match:
                public_url = match.group(1)
                break

        if not public_url:
            print(f'{YELLOW}[!] Could not automatically capture URL from cloudflared output within 20s.{RESET}')
            print('Check if Docker / frontend is running on port 80 or 8000.')
            return

        print(f'{GREEN}[2/2] Tunnel active!{RESET}')
        print_qr(public_url)

        print(f'{CYAN}======================================================================{RESET}')
        print(f'{BOLD}Tunnel is live! Press Ctrl+C in this terminal to stop sharing.{RESET}')
        print(f'{CYAN}======================================================================{RESET}')

        # Keep alive
        while True:
            time.sleep(1)

    except KeyboardInterrupt:
        print(f'\n\n{YELLOW}[*] Shutting down Cloudflare tunnel...{RESET}')
    finally:
        try:
            process.terminate()
        except Exception:
            pass
        print(f'{GREEN}[OK] Tunnel closed.{RESET}')

if __name__ == '__main__':
    main()
