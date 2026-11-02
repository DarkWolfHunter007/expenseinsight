# ExpenseInsight: Startup Guide (Windows & Mac)

Run ExpenseInsight on your own computer with Docker, then optionally share it over the internet
with Cloudflare Tunnel. Everything runs on **your** machine: your statements and data never leave it
except when someone you shared the link with opens the site.

| What | Address |
|---|---|
| The app (website + API) | http://localhost:3000 |
| API docs (Swagger) | http://localhost:8000/docs |
| Health check | http://localhost:3000/health |

---

## 1. What you need

| | Windows 10/11 | macOS (Apple Silicon or Intel) |
|---|---|---|
| Docker Desktop | `winget install Docker.DockerDesktop` (needs WSL 2, the installer offers it) | `brew install --cask docker` |
| Git (optional, to download the code) | `winget install Git.Git` | comes with Xcode tools: `xcode-select --install` |
| cloudflared (only to share online) | `winget install Cloudflare.cloudflared` | `brew install cloudflared` |
| Python (only for the QR-code helper) | optional | optional |

No Python or Flutter install is needed to run the app. Docker builds everything.

Homebrew, if you don't have it (Mac):
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

After installing Docker Desktop, **open it once and wait until it says "Engine running"** (green).
Docker must be running every time you use the app.

---

## 2. First-time setup

### Get the code
```bash
git clone https://github.com/DarkWolfHunter007/expenseinsight.git
cd expenseinsight
```
(Or just open the project folder you already have.)

### Create your secret key (do this once)
The key signs login tokens. Without it the app uses an insecure built-in default, which is fine on
your own computer but **not** if you share the app online.

**Windows (PowerShell), in the project folder:**
```powershell
$b = New-Object byte[] 32
[Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($b)
$secret = ($b | ForEach-Object { $_.ToString('x2') }) -join ''
Set-Content -Path .env -Value "JWT_SECRET_KEY=$secret" -Encoding ascii
```

**Mac (Terminal), in the project folder:**
```bash
echo "JWT_SECRET_KEY=$(openssl rand -hex 32)" > .env
```

The `.env` file is ignored by git, so it never gets committed. Keep it private. If you change or
delete it, everyone is signed out (their data is not lost).

### Start the app
```bash
docker compose up --build -d
```
The first build takes a few minutes. Then check it:
```bash
docker compose ps          # both containers should be "Up", backend "healthy"
```
Open **http://localhost:3000**, enter your email, and upload a bank statement PDF.

---

## 3. Everyday commands

| Task | Command |
|---|---|
| Start | `docker compose up -d` |
| Stop | `docker compose stop` |
| Stop and remove containers (data is kept) | `docker compose down` |
| See logs | `docker compose logs -f backend` |
| Update after changing code | `docker compose up --build -d` |
| Run the backend tests | `docker compose exec backend pytest backend/tests -q` |

After an update, press **Ctrl+Shift+R** (Windows) or **Cmd+Shift+R** (Mac) once in the browser.

### Where your data lives
Everything is in the `data/` folder inside the project: the SQLite database
(`data/expenseinsight.db`) and the uploaded PDFs (`data/uploads/`). It survives restarts and rebuilds.

**Back it up** by copying that folder while the app is stopped (`docker compose stop`).
To start completely fresh, stop the app and delete `data/`.

---

## 4. Share it online with Cloudflare

One tunnel is enough: the website and the API are both served on port 3000, so people only need the
one link. Your computer must stay on, awake, and running Docker for the link to work.

### Option A: Quick tunnel (free, no account, 1 minute)

Make sure the app is running (section 2), then:

```bash
cloudflared tunnel --url http://localhost:3000
```
After a few seconds it prints a link like `https://random-words.trycloudflare.com`. Send that link.
Press **Ctrl+C** to stop sharing.

Or, for a QR code you can scan with a phone:
```bash
python share_live.py
```
(It installs the `qrcode` package the first time and shares port 3000, the same as above.)

Good to know:
- The link **changes every time** you start the tunnel and is meant for testing, not permanent use.
- It is HTTPS, so browser notifications for budget alerts work for the people you share it with.

### Option B: Permanent link on your own domain (free Cloudflare account + a domain)

You need a domain whose DNS is managed by Cloudflare. Then, once:

```bash
cloudflared tunnel login                              # opens the browser, pick your domain
cloudflared tunnel create expenseinsight              # prints a tunnel ID
cloudflared tunnel route dns expenseinsight expenses.yourdomain.com
```

Create the config file:
- Windows: `C:\Users\<you>\.cloudflared\config.yml`
- Mac: `~/.cloudflared/config.yml`

```yaml
tunnel: <TUNNEL-ID>
credentials-file: <path to the .json file printed by "tunnel create">
ingress:
  - hostname: expenses.yourdomain.com
    service: http://localhost:3000
  - service: http_status:404
```

Run it:
```bash
cloudflared tunnel run expenseinsight
```

To start it automatically when the computer boots:
- Windows (PowerShell **as Administrator**): `cloudflared service install`
- Mac: `sudo cloudflared service install`

### Protect it before you share it (strongly recommended)

ExpenseInsight signs people in with **just an email address, with no password**. Anyone who has your
link and knows an email can open that email's account. For friends and family, put Cloudflare Access
in front so people must prove who they are first (it has a free tier, up to 50 users at the time of
writing; check Cloudflare's pricing page):

1. Use Option B (a named tunnel on your domain).
2. Cloudflare dashboard → **Zero Trust** → **Access** → **Applications** → **Add an application** → **Self-hosted**.
3. Set the hostname to `expenses.yourdomain.com`.
4. Add a policy: **Allow**, **Emails**, and list the exact email addresses you trust.
5. Visitors then get a one-time code by email before they can even see the site.

Also keep your `.env` secret key set (section 2), and don't share the link publicly.

---

## 5. Troubleshooting

| Problem | Fix |
|---|---|
| `failed to connect to the docker API` / `dockerDesktopLinuxEngine` | Docker Desktop isn't running. Open it and wait for "Engine running". |
| Port 3000, 80 or 8000 already in use | Something else is using it. Stop it (a leftover dev server is a common cause), then `docker compose up -d`. |
| Page says `Failed to fetch … 127.0.0.1:8000` | The browser saved an old server address. Open **More → Server Connection** and clear it, or clear this site's data in the browser. |
| Page looks old or icons are missing after an update | Hard refresh: Ctrl+Shift+R (Windows) / Cmd+Shift+R (Mac). |
| `cloudflared` is not recognized | Close and reopen the terminal after installing, or run `winget install Cloudflare.cloudflared` / `brew install cloudflared` again. |
| The shared link stopped working | The quick-tunnel link changes each run. Start a new tunnel. Also check Docker is running and the computer isn't asleep. |
| Backend shows `unhealthy` | `docker compose logs backend` shows why. If you changed code, run `docker compose up --build -d`. |
| Everyone got signed out | The `JWT_SECRET_KEY` in `.env` changed or was removed. People just sign in again, and their data is unaffected. |
| Apple Silicon (M1-M4) build problems | The images are multi-architecture and should work as is. Make sure Docker Desktop is the Apple Silicon version. |

---

## 6. Running without Docker (developers)

See [README.md](README.md) (Option 3: Python backend + Flutter) and [SETUP_MAC.md](SETUP_MAC.md).
The app is web-only: it works in any modern browser, and can be installed as an app from the
browser's menu ("Install app" / "Add to Home Screen").
