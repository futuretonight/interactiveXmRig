#!/usr/bin/env bash
# ============================================================
#  XMRig Termux Auto-Setup  |  github.com/YOUR_USERNAME/xmrig-termux-setup
#  Detects your device, asks only what it needs, builds & launches.
# ============================================================

# ── Colours & helpers ───────────────────────────────────────
RED='\033[0;31m';  GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BLUE='\033[0;34m';  BOLD='\033[1m';  DIM='\033[2m'
MAGENTA='\033[0;35m'; WHITE='\033[1;37m'; NC='\033[0m'

OK()   { echo -e "${GREEN}  ✔  ${NC}$*"; }
INFO() { echo -e "${CYAN}  ℹ  ${NC}$*"; }
WARN() { echo -e "${YELLOW}  ⚠  ${NC}$*"; }
ERR()  { echo -e "${RED}  ✖  ${NC}$*"; }
STEP() { echo -e "\n${BOLD}${BLUE}━━  $*  ━━${NC}"; }
HR()   { echo -e "${DIM}────────────────────────────────────────────────────${NC}"; }

banner() {
cat << 'EOF'

  ██╗  ██╗███╗   ███╗██████╗ ██╗ ██████╗
  ╚██╗██╔╝████╗ ████║██╔══██╗██║██╔════╝
   ╚███╔╝ ██╔████╔██║██████╔╝██║██║  ███╗
   ██╔██╗ ██║╚██╔╝██║██╔══██╗██║██║   ██║
  ██╔╝ ██╗██║ ╚═╝ ██║██║  ██║██║╚██████╔╝
  ╚═╝  ╚═╝╚═╝     ╚═╝╚═╝  ╚═╝╚═╝ ╚═════╝
       Termux Auto-Setup  ·  Android Edition
EOF
echo -e "${DIM}  Autonomous · Interactive · Optimised${NC}\n"
}

# ── Sanity: must run in Termux ───────────────────────────────
if [[ -z "$PREFIX" || ! -d "/data/data/com.termux" ]]; then
  ERR "This script must be run inside Termux on Android."
  exit 1
fi

banner

# ── 1. Device Analysis ───────────────────────────────────────
STEP "Analysing your device"

CPU_CORES=$(nproc 2>/dev/null || grep -c ^processor /proc/cpuinfo)
TOTAL_RAM_MB=$(awk '/MemTotal/{printf "%d", $2/1024}' /proc/meminfo)
FREE_RAM_MB=$(awk '/MemAvailable/{printf "%d", $2/1024}' /proc/meminfo)
CPU_MODEL=$(grep -m1 "Hardware\|model name\|Processor" /proc/cpuinfo 2>/dev/null \
            | sed 's/.*: //' | head -c 60)
ARCH=$(uname -m)

# ── Determine RandomX mode ───────────────────────────────────
# RandomX fast mode needs ~2 GB per thread dataset; light = ~256 MB total
# On Android <4 GB RAM, light is safer and still effective.
if   (( TOTAL_RAM_MB >= 6000 )); then RX_MODE="fast";  RX_LABEL="Fast  (full dataset in RAM)"
elif (( TOTAL_RAM_MB >= 3500 )); then RX_MODE="auto";  RX_LABEL="Auto  (xmrig decides at runtime)"
else                                   RX_MODE="light"; RX_LABEL="Light (safe for low-RAM devices)"
fi

# ── Smart thread recommendation ──────────────────────────────
# Leave at least 1 core free so Android doesn't kill the process
RECOMMENDED_THREADS=$(( CPU_CORES > 1 ? CPU_CORES - 1 : 1 ))

# If low RAM, further reduce (RandomX light ~256 MB overhead per thread)
if (( TOTAL_RAM_MB < 2048 )) && (( RECOMMENDED_THREADS > 2 )); then
  RECOMMENDED_THREADS=2
fi

# make -j value (use all cores for compilation, it's temporary)
MAKE_JOBS=$(( CPU_CORES > 0 ? CPU_CORES : 4 ))

echo -e "  ${WHITE}CPU       ${NC}${CPU_MODEL:-Unknown}"
echo -e "  ${WHITE}Arch      ${NC}${ARCH}"
echo -e "  ${WHITE}Cores     ${NC}${CPU_CORES}"
echo -e "  ${WHITE}Total RAM ${NC}${TOTAL_RAM_MB} MB"
echo -e "  ${WHITE}Free  RAM ${NC}${FREE_RAM_MB} MB"
echo -e "  ${WHITE}RX Mode   ${NC}${RX_LABEL}"
echo -e "  ${WHITE}Threads ✦ ${NC}${RECOMMENDED_THREADS}  (recommended)"
HR

# ── 2. Interactive Configuration ─────────────────────────────
STEP "Mining configuration"

ask() {
  local prompt="$1" default="$2" var_name="$3"
  if [[ -n "$default" ]]; then
    echo -ne "  ${CYAN}${prompt}${NC} ${DIM}[${default}]${NC}: "
  else
    echo -ne "  ${CYAN}${prompt}${NC}: "
  fi
  read -r input
  input="${input:-$default}"
  eval "$var_name=\"\$input\""
}

ask_yn() {
  local prompt="$1" default="$2"
  echo -ne "  ${CYAN}${prompt}${NC} ${DIM}[${default}]${NC}: "
  read -r yn
  yn="${yn:-$default}"
  [[ "$yn" =~ ^[Yy]$ ]]
}

echo -e "  ${DIM}Press ENTER to accept the bracketed default.${NC}\n"

ask "Pool URL (host:port)" "xmr-asia1.nanopool.org:14433" POOL
ask "Wallet address" "" WALLET
while [[ -z "$WALLET" ]]; do
  WARN "Wallet address cannot be empty."
  ask "Wallet address" "" WALLET
done
ask "Worker / rig name" "android" WORKER
ask "Password" "x" PASS

echo ""
if ask_yn "Use TLS (recommended for supported pools)?" "Y"; then
  TLS_FLAG="--tls"
  TLS_LABEL="Yes"
else
  TLS_FLAG=""
  TLS_LABEL="No"
fi

ask "Mining threads" "$RECOMMENDED_THREADS" THREADS
# Validate threads is a number within range
if ! [[ "$THREADS" =~ ^[0-9]+$ ]] || (( THREADS < 1 )) || (( THREADS > CPU_CORES * 2 )); then
  WARN "Invalid value — falling back to recommended: ${RECOMMENDED_THREADS}"
  THREADS=$RECOMMENDED_THREADS
fi

ask "CPU priority (0=idle … 5=realtime, default 3)" "3" CPU_PRIORITY
if ! [[ "$CPU_PRIORITY" =~ ^[0-5]$ ]]; then CPU_PRIORITY=3; fi

ask "CPU max-threads hint % (throttle, 100 = full)" "100" CPU_HINT
if ! [[ "$CPU_HINT" =~ ^[0-9]+$ ]] || (( CPU_HINT < 1 || CPU_HINT > 100 )); then CPU_HINT=100; fi

echo -e "\n  ${DIM}Algorithm is fixed to RandomX (rx/0) — optimal for XMR.${NC}"
ALGO="rx/0"

HR
echo -e "\n  ${WHITE}${BOLD}Configuration Summary${NC}"
echo -e "  Pool      → ${YELLOW}${POOL}${NC}"
echo -e "  Wallet    → ${YELLOW}${WALLET:0:16}…${NC}"
echo -e "  Worker    → ${YELLOW}${WORKER}${NC}"
echo -e "  Algo      → ${YELLOW}${ALGO}${NC}"
echo -e "  Threads   → ${YELLOW}${THREADS}${NC}"
echo -e "  RX mode   → ${YELLOW}${RX_MODE}${NC}"
echo -e "  TLS       → ${YELLOW}${TLS_LABEL}${NC}"
echo -e "  Priority  → ${YELLOW}${CPU_PRIORITY}${NC}"
echo ""

if ! ask_yn "Looks good — proceed with installation?" "Y"; then
  INFO "Aborted. Re-run setup.sh to start over."
  exit 0
fi

# ── 3. Package Installation ──────────────────────────────────
STEP "Updating & installing packages"

run_cmd() {
  echo -e "  ${DIM}» $*${NC}"
  if ! "$@" 2>&1 | sed 's/^/    /'; then
    ERR "Command failed: $*"
    exit 1
  fi
}

INFO "Running apt update …"
run_cmd apt-get update -y

INFO "Running apt upgrade …"
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -o Dpkg::Options::="--force-confnew" 2>&1 | \
  grep -E "upgraded|newly|removed|not upgraded|error" | sed 's/^/    /' || true

INFO "Installing build dependencies …"
run_cmd pkg install -y git build-essential cmake

INFO "Second apt upgrade (post-install) …"
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -o Dpkg::Options::="--force-confnew" 2>&1 | \
  grep -E "upgraded|newly|removed|not upgraded|error" | sed 's/^/    /' || true

OK "All packages installed."

# ── 4. Clone XMRig ───────────────────────────────────────────
STEP "Cloning XMRig source"

XMRIG_DIR="$HOME/xmrig"
if [[ -d "$XMRIG_DIR" ]]; then
  WARN "Directory ${XMRIG_DIR} already exists — pulling latest instead of cloning."
  git -C "$XMRIG_DIR" pull
else
  INFO "Cloning from https://github.com/xmrig/xmrig …"
  git clone --depth 1 https://github.com/xmrig/xmrig.git "$XMRIG_DIR"
fi
OK "Source ready at ${XMRIG_DIR}"

# ── 5. Build ─────────────────────────────────────────────────
STEP "Building XMRig  (this can take 5–20 min on older devices)"

BUILD_DIR="$XMRIG_DIR/build"
mkdir -p "$BUILD_DIR"

INFO "Running cmake …"
cd "$BUILD_DIR" || exit 1
cmake .. -DWITH_HWLOC=OFF 2>&1 | tail -5 | sed 's/^/    /'

INFO "Running make -j${MAKE_JOBS} …"
echo -e "  ${DIM}Watch the progress — do not lock your screen.${NC}"

# Show a simple spinner alongside make
make -j"${MAKE_JOBS}" 2>&1 | \
  awk 'BEGIN{n=0} /^\[/{n++; printf "\r  \033[0;36m[%d%%]\033[0m %s      ", $0+0, substr($0,5,40)} END{print ""}' &

MAKE_PID=$!
wait $MAKE_PID 2>/dev/null || true

# Verify binary
BINARY="$BUILD_DIR/xmrig"
if [[ ! -x "$BINARY" ]]; then
  ERR "Build failed — xmrig binary not found at ${BINARY}"
  ERR "Try running: cd ~/xmrig/build && make -j4  (and check errors above)"
  exit 1
fi

OK "Build complete → ${BINARY}"

# ── 6. Generate mine.sh launcher ────────────────────────────
STEP "Generating personalised launcher"

MINE_SCRIPT="$HOME/mine.sh"

cat > "$MINE_SCRIPT" << LAUNCHER
#!/usr/bin/env bash
# Auto-generated by setup.sh — edit freely.
# Generated: $(date)

XMRIG="$BINARY"
POOL="$POOL"
WALLET="$WALLET"
WORKER="$WORKER"
ALGO="$ALGO"
PASS="$PASS"
THREADS="$THREADS"
CPU_PRIORITY="$CPU_PRIORITY"
CPU_HINT="$CPU_HINT"
RX_MODE="$RX_MODE"
TLS="$TLS_FLAG"

echo ""
echo -e "\033[1;33m  ⛏  Starting XMRig — \${THREADS} thread(s) on \${POOL}\033[0m"
echo ""

exec "\$XMRIG" \\
  -o "\${POOL}" \\
  -a "\${ALGO}" \\
  -u "\${WALLET}.\${WORKER}" \\
  -p "\${PASS}" \\
  \${TLS} \\
  --threads="\${THREADS}" \\
  --cpu-priority="\${CPU_PRIORITY}" \\
  --cpu-max-threads-hint="\${CPU_HINT}" \\
  --randomx-mode="\${RX_MODE}" \\
  --randomx-wrmsr=-1 \\
  --retries=2 \\
  --retry-pause=2 \\
  --print-time=30 \\
  --keepalive
LAUNCHER

chmod +x "$MINE_SCRIPT"
OK "Launcher saved → ${MINE_SCRIPT}"

# ── 7. Final summary ─────────────────────────────────────────
echo ""
HR
echo -e "${GREEN}${BOLD}  ✔  Setup complete!${NC}"
HR
echo -e ""
echo -e "  ${BOLD}Start mining anytime:${NC}"
echo -e "    ${YELLOW}bash ~/mine.sh${NC}"
echo ""
echo -e "  ${BOLD}Edit settings later:${NC}"
echo -e "    ${YELLOW}nano ~/mine.sh${NC}"
echo ""
echo -e "  ${BOLD}Tips for Android stability:${NC}"
echo -e "  ${DIM}• Enable 'Acquire Wakelock' in Termux notification${NC}"
echo -e "  ${DIM}• Disable battery optimisation for Termux in Android Settings${NC}"
echo -e "  ${DIM}• Keep screen on or use a wake-lock app${NC}"
echo -e "  ${DIM}• Reduce threads if Android kills the process${NC}"
echo ""

if ask_yn "Start mining now?" "Y"; then
  bash "$MINE_SCRIPT"
fi
