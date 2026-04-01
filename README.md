# ⛏ XMRig Termux Auto-Setup

> One-command, interactive XMRig installer for **Android + Termux**.  
> Detects your device, optimises threads & RandomX mode, builds from source, and generates a ready-to-run launcher.

---

## Requirements

| What | Where to get it |
|---|---|
| Android 7+ | Your phone |
| [Termux](https://f-droid.org/packages/com.termux/) | **F-Droid only** (Play Store version is outdated) |
| Internet connection | Any Wi-Fi or mobile data |

> **Important:** Install Termux from [F-Droid](https://f-droid.org/packages/com.termux/), **not** the Google Play Store. The Play Store version is frozen and will break the build.

---

## Quick Start

Open Termux and run these three commands:

```bash
# 1 — install git (the only manual step)
pkg install git -y

# 2 — clone this repo
git clone https://github.com/YOUR_USERNAME/xmrig-termux-setup.git

# 3 — run the setup
bash xmrig-termux-setup/setup.sh
```

The script will handle **everything else** automatically.

---

## What the Script Does

```
1. Detects your hardware
   └─ CPU model, core count, total/free RAM, architecture

2. Recommends optimal settings
   └─ Thread count   →  cores − 1  (keeps Android stable)
   └─ RandomX mode   →  fast / auto / light  (based on your RAM)

3. Updates & installs packages
   └─ apt update → apt upgrade → git, build-essential, cmake → apt upgrade

4. Clones XMRig from GitHub
   └─ https://github.com/xmrig/xmrig  (latest source, shallow clone)

5. Builds XMRig
   └─ cmake .. -DWITH_HWLOC=OFF
   └─ make -j<your_core_count>

6. Asks you interactive questions
   └─ Pool URL · Wallet address · Worker name · TLS on/off
   └─ Thread count (confirm or override the recommendation)
   └─ CPU priority · CPU max-threads hint

7. Generates ~/mine.sh
   └─ Personalised launcher with all your settings baked in

8. Optionally starts mining immediately
```

---

## After Setup

```bash
# Start mining
bash ~/mine.sh

# Edit your config (pool / wallet / threads / etc.)
nano ~/mine.sh
```

---

## RandomX Mode Explained

| Your RAM | Mode chosen | Notes |
|---|---|---|
| ≥ 6 GB | **fast** | Full dataset in RAM — highest hashrate |
| 3.5 – 6 GB | **auto** | XMRig decides at runtime |
| < 3.5 GB | **light** | Safe; slightly lower hashrate |

---

## Thread Recommendations

| Cores | Recommended threads | Why |
|---|---|---|
| 8 | 7 | 1 free core keeps Android responsive |
| 4 | 3 | Same logic |
| 2 | 1 | Prevents Android OOM kill |

You can always override at the prompt. Fewer threads = cooler phone + less risk of the process being killed.

---

## Android Stability Tips

- **Enable Wakelock** — tap the Termux notification and enable *Acquire Wakelock*
- **Disable battery optimisation** for Termux in *Android Settings → Apps → Termux → Battery*
- **Keep the screen on** or use a wake-lock app during mining
- If Android kills the process, reduce `--threads` by 1 in `~/mine.sh`
- Plug in your charger — mining drains the battery fast

---

## Supported Pools (examples)

| Pool | URL:Port (TLS) |
|---|---|
| Nanopool | `xmr-asia1.nanopool.org:14433` |
| SupportXMR | `pool.supportxmr.com:443` |
| MoneroOcean | `gulf.moneroocean.stream:10128` |
| Unmineable (BTC payout) | `rx.unmineable.com:443` |

---

## Troubleshooting

| Problem | Fix |
|---|---|
| `cmake` not found | `pkg install cmake -y` |
| `make` errors with `-maes` | Your CPU doesn't support AES; xmrig falls back automatically |
| Binary not found after build | `cd ~/xmrig/build && make -j2` and check errors |
| Mining stops after a few minutes | Disable battery optimisation for Termux; reduce thread count |
| Very slow build | Normal on older devices — can take up to 20 min |

---

## Disclaimer

This script compiles and runs XMRig solely for **legitimate, authorised Monero (XMR) mining** on hardware you own. Mining without permission on shared or institutional networks may violate terms of service. The authors take no responsibility for misuse.

---

## Credits

- [XMRig](https://github.com/xmrig/xmrig) — the miner itself
- Termux community for documenting the Android build process
