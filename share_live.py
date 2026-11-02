import os
import re
import sys
import time
import subprocess
import shutil
import socket
import struct
import threading

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

def drain_output(stream, connected: threading.Event):
    """Keep reading cloudflared's output. If nobody reads it the pipe fills up, cloudflared freezes
    before it finishes connecting, and the public link shows a Cloudflare 530 error forever.
    Sets `connected` as soon as cloudflared reports that the tunnel is registered."""
    try:
        for line in stream:
            if 'Registered tunnel connection' in line:
                connected.set()
    except Exception:
        pass


def resolves_on_public_dns(host: str, server: str = '1.1.1.1', timeout: float = 2.0) -> bool:
    """Asks Cloudflare's DNS directly whether the new link exists yet.

    Never ask this PC's own resolver: a lookup that arrives a moment too early is answered "no such
    name", Windows remembers that for about a minute, and neither this script nor your browser can
    open the link until it expires."""
    query_id = os.urandom(2)
    header = query_id + struct.pack('!HHHHH', 0x0100, 1, 0, 0, 0)
    question = b''.join(bytes([len(part)]) + part.encode() for part in host.split('.')) + b'\x00' + struct.pack('!HH', 1, 1)
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
        sock.settimeout(timeout)
        sock.sendto(header + question, (server, 53))
        data, _ = sock.recvfrom(512)
    if data[:2] != query_id:
        return False
    rcode = data[3] & 0x0F
    answers = struct.unpack('!H', data[6:8])[0]
    return rcode == 0 and answers > 0


def announce_when_ready(url: str, give_up_after: int = 240):
    """Runs in the background and prints a green check once the new link exists in public DNS.

    A brand-new trycloudflare.com name takes anywhere from about 8 to 60+ seconds to appear, and that
    delay is on Cloudflare's side. Opening the link before then shows a Cloudflare 530 error."""
    host = url.replace('https://', '')
    started = time.time()
    dns_errors = 0
    while time.time() - started < give_up_after:
        try:
            if resolves_on_public_dns(host):
                print(f'\n{GREEN}{BOLD}\u2705 The link is working now ({int(time.time() - started)}s after the tunnel connected): {url}{RESET}')
                return
        except OSError:
            dns_errors += 1
            if dns_errors >= 3:  # public DNS is blocked on this network, so we cannot tell
                print(f'\n{YELLOW}Could not check the link automatically. Try opening it in a minute.{RESET}')
                return
        time.sleep(1)
    print(f'\n{YELLOW}The link still is not reachable after {give_up_after}s. Stop (Ctrl+C) and run the script again.{RESET}')


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

    # 1. Target Port resolution (the app is served on port 3000; the API is also reachable on 8000)
    target_port = 3000
    if len(sys.argv) > 1:
        try:
            target_port = int(sys.argv[1])
        except ValueError:
            target_port = 3000

    # 2. Check cloudflared binary
    cloudflared_bin = check_cloudflared()
    if not cloudflared_bin:
        print(f'{YELLOW}[!] Cloudflare Tunnel CLI (cloudflared) is not detected.{RESET}')
        print(f'{GREEN}To install in 10 seconds via PowerShell, run:{RESET}')
        print(f'   {BOLD}winget install Cloudflare.cloudflared{RESET}\n')
        print(f'Or download from: https://github.com/cloudflare/cloudflared/releases\n')
        return

    print(f'{BLUE}[1/3] Connecting Cloudflare Tunnel to port {target_port}...{RESET}')
    
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
            print('Check that Docker is running and the app opens at http://localhost:3000.')
            return

        # Keep draining cloudflared's output in the background for as long as the tunnel runs
        connected = threading.Event()
        threading.Thread(target=drain_output, args=(process.stdout, connected), daemon=True).start()

        print(f'{BLUE}[2/3] Link created, connecting the tunnel...{RESET}')
        if connected.wait(30):
            print(f'{GREEN}[3/3] Tunnel connected.{RESET}')
        else:
            print(f'{YELLOW}[3/3] cloudflared has not confirmed the connection yet, showing the link anyway.{RESET}')
        print_qr(public_url)
        print(f'{YELLOW}{BOLD}\u23f3 A new link needs about 10 to 60 seconds to appear on the internet.{RESET}')
        print(f'{YELLOW}   Wait for the green check below before opening it, or you will see a Cloudflare 530 error.{RESET}')
        threading.Thread(target=announce_when_ready, args=(public_url,), daemon=True).start()

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
