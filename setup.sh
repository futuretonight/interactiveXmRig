#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════════╗
# ║         XMRig Termux Auto-Setup  ·  Android Edition              ║
# ║                                                                  ║
# ║  Script by  ░▒▓  FutureTonight  ▓▒░                              ║
# ║  github.com/futuretonight/interactiveXmRig                       ║
# ║  Build it once. Mine forever.                                    ║
# ╚══════════════════════════════════════════════════════════════════╝

# ── Colour palette ─────────────────────────────────────────────────
RED='\033[0;31m';     GREEN='\033[0;32m';   YELLOW='\033[1;33m'
CYAN='\033[0;36m';    BLUE='\033[0;34m';    BOLD='\033[1m'
DIM='\033[2m';        MAGENTA='\033[0;35m'; WHITE='\033[1;37m'
BG_DARK='\033[48;5;234m'; LBLUE='\033[38;5;75m'; ORANGE='\033[38;5;214m'
TEAL='\033[38;5;43m'; PINK='\033[38;5;205m'; LGRAY='\033[38;5;245m'
NC='\033[0m'

# ── Log helpers ────────────────────────────────────────────────────
OK()    { echo -e "  ${GREEN}▸ ${NC}${WHITE}$*${NC}"; }
INFO()  { echo -e "  ${LBLUE}◈ ${NC}${LGRAY}$*${NC}"; }
WARN()  { echo -e "  ${ORANGE}⚡ ${NC}${YELLOW}$*${NC}"; }
ERR()   { echo -e "  ${RED}✖ ${NC}${RED}$*${NC}"; }
LABEL() { printf "  ${TEAL}%-18s${NC} ${WHITE}%s${NC}\n" "$1" "$2"; }
BADGE() { echo -e "  ${BG_DARK}${BOLD}${CYAN}  $*  ${NC}"; }
HR()    { echo -e "${DIM}  ──────────────────────────────────────────────────────${NC}"; }
BR()    { echo ""; }

STEP() {
  BR
  echo -e "${BOLD}${LBLUE}  ┌─────────────────────────────────────────────────────┐${NC}"
  printf  "${BOLD}${LBLUE}  │  ${PINK}%-51s${LBLUE}│${NC}\n" "$*"
  echo -e "${BOLD}${LBLUE}  └─────────────────────────────────────────────────────┘${NC}"
  BR
}

# ── Sanity: must run in Termux ──────────────────────────────────────
if [[ -z "$PREFIX" || ! -d "/data/data/com.termux" ]]; then
  ERR "This script must be run inside Termux on Android."
  exit 1
fi

# ══════════════════════════════════════════════════════════════════════
#  BANNER
# ══════════════════════════════════════════════════════════════════════
clear
echo -e "${BOLD}${LBLUE}"
cat << 'EOF'
  ██╗  ██╗███╗   ███╗██████╗ ██╗ ██████╗
  ╚██╗██╔╝████╗ ████║██╔══██╗██║██╔════╝
   ╚███╔╝ ██╔████╔██║██████╔╝██║██║  ███╗
   ██╔██╗ ██║╚██╔╝██║██╔══██╗██║██║   ██║
  ██╔╝ ██╗██║ ╚═╝ ██║██║  ██║██║╚██████╔╝
  ╚═╝  ╚═╝╚═╝     ╚═╝╚═╝  ╚═╝╚═╝ ╚═════╝
EOF
echo -e "${NC}"
echo -e "  ${TEAL}Termux Auto-Setup${NC}  ${DIM}·${NC}  ${PINK}Android Edition${NC}"
echo -e "  ${DIM}Script crafted by ${NC}${BOLD}${ORANGE}FutureTonight${NC}${DIM} · Build it once. Mine forever.${NC}"
HR
BR

# ══════════════════════════════════════════════════════════════════════
#  WALLET CACHE  (~/.xmrig_wallets)
# ══════════════════════════════════════════════════════════════════════
WALLET_CACHE="$HOME/.xmrig_wallets"
[[ ! -f "$WALLET_CACHE" ]] && touch "$WALLET_CACHE"

load_wallets() {
  mapfile -t WALLET_NAMES < <(awk -F'=' '{print $1}' "$WALLET_CACHE" 2>/dev/null)
  mapfile -t WALLET_ADDRS < <(awk -F'=' '{print $2}' "$WALLET_CACHE" 2>/dev/null)
}

save_wallet() {
  local name="$1" addr="$2"
  # Remove existing entry with same name
  sed -i "/^${name}=/d" "$WALLET_CACHE" 2>/dev/null || true
  echo "${name}=${addr}" >> "$WALLET_CACHE"
}

delete_wallet() {
  local name="$1"
  sed -i "/^${name}=/d" "$WALLET_CACHE" 2>/dev/null || true
}

show_wallets() {
  load_wallets
  if [[ ${#WALLET_NAMES[@]} -eq 0 ]]; then
    INFO "No saved wallets yet."
    return
  fi
  BR
  echo -e "  ${BOLD}${TEAL}Saved Wallets${NC}"
  HR
  for i in "${!WALLET_NAMES[@]}"; do
    local addr="${WALLET_ADDRS[$i]}"
    local preview="${addr:0:20}…${addr: -6}"
    printf "  ${LBLUE}[%d]${NC}  ${WHITE}%-18s${NC}  ${DIM}%s${NC}\n" \
      "$((i+1))" "${WALLET_NAMES[$i]}" "$preview"
  done
  HR
}

# ══════════════════════════════════════════════════════════════════════
#  STEP 1 · DEVICE ANALYSIS
# ══════════════════════════════════════════════════════════════════════
STEP "01  ·  Analysing Your Device"

# ── Core count (read every line to handle hotplug gaps on big.LITTLE)
CPU_CORES=$(grep -c "^processor" /proc/cpuinfo 2>/dev/null || nproc 2>/dev/null || echo 4)

# ── RAM
TOTAL_RAM_MB=$(awk '/MemTotal/{printf "%d", $2/1024}' /proc/meminfo)
FREE_RAM_MB=$(awk '/MemAvailable/{printf "%d", $2/1024}' /proc/meminfo)
USED_RAM_MB=$(( TOTAL_RAM_MB - FREE_RAM_MB ))

# ── Architecture
ARCH=$(uname -m)

# ── CPU model — multi-layer fallback for Snapdragon / Qualcomm
#   Layer 1: Android system property (most accurate, API 31+)
CPU_MODEL=$(getprop ro.soc.model 2>/dev/null | tr -d '[:cntrl:]' | xargs)

#   Layer 2: board platform → friendly Snapdragon name
if [[ -z "$CPU_MODEL" || "$CPU_MODEL" == "0" ]]; then
  BOARD=$(getprop ro.board.platform 2>/dev/null | tr '[:upper:]' '[:lower:]' | xargs)
  case "$BOARD" in
    sm8750*)  CPU_MODEL="Snapdragon 8 Elite" ;;
    sm8650*)  CPU_MODEL="Snapdragon 8 Gen 3" ;;
    sm8550*)  CPU_MODEL="Snapdragon 8 Gen 2" ;;
    sm8475*)  CPU_MODEL="Snapdragon 8+ Gen 1" ;;
    sm8450*)  CPU_MODEL="Snapdragon 8 Gen 1" ;;
    sm8350*)  CPU_MODEL="Snapdragon 888" ;;
    sm8250*)  CPU_MODEL="Snapdragon 865" ;;
    sm8150*)  CPU_MODEL="Snapdragon 855" ;;
    sm7675*)  CPU_MODEL="Snapdragon 7s Gen 3" ;;
    sm7550*)  CPU_MODEL="Snapdragon 7 Gen 2" ;;
    sm7450*)  CPU_MODEL="Snapdragon 7s Gen 2" ;;
    sm7325*)  CPU_MODEL="Snapdragon 778G" ;;
    sm7225*)  CPU_MODEL="Snapdragon 750G" ;;
    sm6375*)  CPU_MODEL="Snapdragon 695" ;;
    sm6350*)  CPU_MODEL="Snapdragon 690" ;;
    sm6125*)  CPU_MODEL="Snapdragon 662" ;;
    sm6115*)  CPU_MODEL="Snapdragon 662" ;;
    sm4350*)  CPU_MODEL="Snapdragon 480" ;;
    mt*|mediatek*) CPU_MODEL="MediaTek ${BOARD^^}" ;;
    exynos*)  CPU_MODEL="Samsung ${BOARD^^}" ;;
    kirin*)   CPU_MODEL="HiSilicon ${BOARD^^}" ;;
    tensor*)  CPU_MODEL="Google Tensor" ;;
    *)
      if [[ -n "$BOARD" && "$BOARD" != "0" ]]; then
        CPU_MODEL="SoC: ${BOARD^^}"
      fi
      ;;
  esac
fi

#   Layer 3: ro.hardware / ro.product.board
if [[ -z "$CPU_MODEL" || "$CPU_MODEL" == "0" ]]; then
  HW=$(getprop ro.hardware 2>/dev/null | xargs)
  PROD_BOARD=$(getprop ro.product.board 2>/dev/null | xargs)
  [[ -n "$HW"         ]] && CPU_MODEL="HW: $HW"
  [[ -n "$PROD_BOARD" ]] && CPU_MODEL="$PROD_BOARD"
fi

#   Layer 4: /proc/cpuinfo Hardware field
if [[ -z "$CPU_MODEL" || "$CPU_MODEL" == "0" ]]; then
  CPU_MODEL=$(grep -m1 "^Hardware" /proc/cpuinfo 2>/dev/null \
              | sed 's/Hardware\s*:\s*//' | xargs | head -c 60)
fi

#   Layer 5: implementer+part code lookup
if [[ -z "$CPU_MODEL" || "$CPU_MODEL" == "0" ]]; then
  IMPL=$(grep -m1 "^CPU implementer" /proc/cpuinfo 2>/dev/null \
         | awk '{print $NF}')
  PART=$(grep -m1 "^CPU part"        /proc/cpuinfo 2>/dev/null \
         | awk '{print $NF}')
  case "$IMPL" in
    0x51) MFR="Qualcomm (Snapdragon)" ;;
    0x41) MFR="ARM"                   ;;
    0x53) MFR="Samsung"               ;;
    0x4e) MFR="NVIDIA"                ;;
    0x56) MFR="Marvell"               ;;
    0x48) MFR="HiSilicon"             ;;
    *)    MFR="Unknown ($IMPL)"       ;;
  esac
  CPU_MODEL="$MFR (part $PART)"
fi

[[ -z "$CPU_MODEL" ]] && CPU_MODEL="Unknown"

# ── Big.LITTLE cluster detection
PERF_CORES=$(grep "^cpu MHz" /proc/cpuinfo 2>/dev/null \
             | awk '{print $NF}' \
             | awk -F. '{print int($1)}' \
             | sort -rn | head -1)
EFFIC_CORES=$(grep "^cpu MHz" /proc/cpuinfo 2>/dev/null \
              | awk '{print $NF}' \
              | awk -F. '{print int($1)}' \
              | sort -n | head -1)
if [[ -n "$PERF_CORES" && "$PERF_CORES" != "$EFFIC_CORES" ]]; then
  CLUSTER_INFO="  big.LITTLE detected — max ${PERF_CORES} MHz / min ${EFFIC_CORES} MHz"
else
  CLUSTER_INFO=""
fi

# ── RandomX mode selection
if   (( TOTAL_RAM_MB >= 6000 )); then RX_MODE="fast";  RX_LABEL="Fast  · full dataset in RAM"
elif (( TOTAL_RAM_MB >= 3500 )); then RX_MODE="auto";  RX_LABEL="Auto  · xmrig decides at runtime"
else                                   RX_MODE="light"; RX_LABEL="Light · safe for low-RAM devices"
fi

# ── Smart thread recommendation
RECOMMENDED_THREADS=$(( CPU_CORES > 1 ? CPU_CORES - 1 : 1 ))
if (( TOTAL_RAM_MB < 2048 )) && (( RECOMMENDED_THREADS > 2 )); then
  RECOMMENDED_THREADS=2
fi
MAKE_JOBS=$(( CPU_CORES > 0 ? CPU_CORES : 4 ))

# ── RAM bar (20-char)
_bar() {
  local cur=$1 total=$2 width=20
  local filled=$(( cur * width / total ))
  local empty=$(( width - filled ))
  printf "${GREEN}"
  printf '█%.0s' $(seq 1 $filled  2>/dev/null) 2>/dev/null || printf '%0.s█' {1..$filled}
  printf "${DIM}"
  printf '░%.0s' $(seq 1 $empty   2>/dev/null) 2>/dev/null || printf '%0.s░' {1..$empty}
  printf "${NC}"
}
RAM_BAR=$(_bar $USED_RAM_MB $TOTAL_RAM_MB)

# ── Print device summary
LABEL "  CPU Model"   "$CPU_MODEL"
LABEL "  Architecture" "$ARCH"
LABEL "  CPU Cores"   "[${CPU_CORES}/${CPU_CORES}] total"
LABEL "  RAM Usage"   "[${USED_RAM_MB}/${TOTAL_RAM_MB} MB]  ${RAM_BAR}"
LABEL "  Free RAM"    "${FREE_RAM_MB} MB available"
LABEL "  RandomX Mode" "$RX_LABEL"
LABEL "  Rec. Threads" "[${RECOMMENDED_THREADS}/${CPU_CORES}] cores"
[[ -n "$CLUSTER_INFO" ]] && echo -e "  ${DIM}${CLUSTER_INFO}${NC}"

# ══════════════════════════════════════════════════════════════════════
#  HELPERS — prompts
# ══════════════════════════════════════════════════════════════════════
ask() {
  local prompt="$1" default="$2" var_name="$3"
  if [[ -n "$default" ]]; then
    echo -ne "  ${TEAL}❯${NC} ${WHITE}${prompt}${NC} ${DIM}[${default}]${NC}: "
  else
    echo -ne "  ${TEAL}❯${NC} ${WHITE}${prompt}${NC}: "
  fi
  read -r input
  input="${input:-$default}"
  eval "$var_name=\"\$input\""
}

ask_yn() {
  # Returns 0 (true) for Yes, 1 (false) for No
  local prompt="$1" default="${2:-Y}"
  local label
  if [[ "$default" =~ ^[Yy]$ ]]; then label="${GREEN}Y${NC}/${DIM}n${NC}"; else label="${DIM}y${NC}/${RED}N${NC}"; fi
  echo -ne "  ${TEAL}❯${NC} ${WHITE}${prompt}${NC} ${DIM}[${NC}${label}${DIM}]${NC}: "
  read -r yn
  yn="${yn:-$default}"
  [[ "$yn" =~ ^[Yy]$ ]]
}

# ══════════════════════════════════════════════════════════════════════
#  STEP 2 · WALLET CONFIGURATION
# ══════════════════════════════════════════════════════════════════════
STEP "02  ·  Wallet Configuration"

load_wallets

WALLET=""
WALLET_NAME_USED=""

if [[ ${#WALLET_NAMES[@]} -gt 0 ]]; then
  show_wallets
  BR
  echo -e "  ${DIM}You have saved wallets. Load one, or enter a new address below.${NC}"
  BR
  ask "Load saved wallet number (or press ENTER to type new)" "" WALLET_CHOICE

  if [[ "$WALLET_CHOICE" =~ ^[0-9]+$ ]]; then
    IDX=$(( WALLET_CHOICE - 1 ))
    if [[ $IDX -ge 0 && $IDX -lt ${#WALLET_NAMES[@]} ]]; then
      WALLET="${WALLET_ADDRS[$IDX]}"
      WALLET_NAME_USED="${WALLET_NAMES[$IDX]}"
      OK "Loaded wallet: ${WALLET_NAME_USED}  (${WALLET:0:18}…)"
    else
      WARN "Invalid selection — please enter a new address."
    fi
  fi
fi

if [[ -z "$WALLET" ]]; then
  while [[ -z "$WALLET" ]]; do
    ask "Wallet address (XMR)" "" WALLET
    [[ -z "$WALLET" ]] && WARN "Wallet address cannot be empty."
  done
  BR
  if ask_yn "Save this wallet for future use?"; then
    ask "Give this wallet a name (e.g. 'main', 'phone1')" "main" WALLET_SAVE_NAME
    save_wallet "$WALLET_SAVE_NAME" "$WALLET"
    OK "Wallet saved as: ${WALLET_SAVE_NAME}"
    WALLET_NAME_USED="$WALLET_SAVE_NAME"
  fi
fi

BR
if [[ ${#WALLET_NAMES[@]} -gt 0 ]] && ask_yn "Manage saved wallets (view/delete)?"; then
  show_wallets
  ask "Enter wallet number to delete (or press ENTER to skip)" "" DEL_CHOICE
  if [[ "$DEL_CHOICE" =~ ^[0-9]+$ ]]; then
    DIDX=$(( DEL_CHOICE - 1 ))
    if [[ $DIDX -ge 0 && $DIDX -lt ${#WALLET_NAMES[@]} ]]; then
      DNAME="${WALLET_NAMES[$DIDX]}"
      delete_wallet "$DNAME"
      OK "Deleted wallet: ${DNAME}"
    fi
  fi
fi

# ══════════════════════════════════════════════════════════════════════
#  STEP 3 · MINING CONFIGURATION
# ══════════════════════════════════════════════════════════════════════
STEP "03  ·  Mining Configuration"

echo -e "  ${DIM}Press ENTER to accept the bracketed default value.${NC}"
BR

ask "Pool URL (host:port)" "xmr-asia1.nanopool.org:14433" POOL
ask "Worker / rig name"    "android"                       WORKER
ask "Pool password"        "x"                             PASS
BR

if ask_yn "Enable TLS (recommended for compatible pools)?"; then
  TLS_FLAG="--tls"; TLS_LABEL="Yes"
else
  TLS_FLAG="";       TLS_LABEL="No"
fi
BR

ask "Mining threads  [1–${CPU_CORES}]" "$RECOMMENDED_THREADS" THREADS
if ! [[ "$THREADS" =~ ^[0-9]+$ ]] || (( THREADS < 1 || THREADS > CPU_CORES * 2 )); then
  WARN "Invalid — falling back to recommended: ${RECOMMENDED_THREADS}"
  THREADS=$RECOMMENDED_THREADS
fi

ask "CPU priority  (0=idle … 5=realtime)" "3" CPU_PRIORITY
if ! [[ "$CPU_PRIORITY" =~ ^[0-5]$ ]]; then CPU_PRIORITY=3; fi

ask "CPU max-thread hint % (throttle, 100=full)" "100" CPU_HINT
if ! [[ "$CPU_HINT" =~ ^[0-9]+$ ]] || (( CPU_HINT < 1 || CPU_HINT > 100 )); then CPU_HINT=100; fi

echo -e "\n  ${DIM}Algorithm locked to RandomX (rx/0) — optimal for XMR.${NC}"
ALGO="rx/0"

# ── Auto-restart toggle
BR
if ask_yn "Enable auto-restart on crash?"; then
  AUTO_RESTART=true; AUTO_RESTART_LABEL="Yes"
else
  AUTO_RESTART=false; AUTO_RESTART_LABEL="No"
fi

# ── Summary
BR
HR
echo -e "  ${BOLD}${WHITE}Configuration Summary${NC}"
HR
LABEL "  Pool"        "$POOL"
LABEL "  Wallet"      "${WALLET:0:18}…${WALLET: -6}"
[[ -n "$WALLET_NAME_USED" ]] && LABEL "  Wallet Name" "$WALLET_NAME_USED"
LABEL "  Worker"      "$WORKER"
LABEL "  Algorithm"   "$ALGO"
LABEL "  Threads"     "[${THREADS}/${CPU_CORES}]"
LABEL "  RX Mode"     "$RX_MODE"
LABEL "  TLS"         "$TLS_LABEL"
LABEL "  Priority"    "$CPU_PRIORITY / 5"
LABEL "  CPU Hint"    "${CPU_HINT}%"
LABEL "  Auto-Restart" "$AUTO_RESTART_LABEL"
HR
BR

if ! ask_yn "Proceed with installation?"; then
  INFO "Aborted. Re-run setup.sh to start over."
  exit 0
fi

# ══════════════════════════════════════════════════════════════════════
#  STEP 4 · PACKAGE INSTALLATION
# ══════════════════════════════════════════════════════════════════════
STEP "04  ·  Updating Packages"

run_cmd() {
  INFO "» $*"
  if ! "$@" 2>&1 | sed 's/^/    /'; then
    ERR "Command failed: $*"
    exit 1
  fi
}

run_cmd apt-get update -y

DEBIAN_FRONTEND=noninteractive apt-get upgrade -y \
  -o Dpkg::Options::="--force-confnew" 2>&1 \
  | grep -E "upgraded|newly|removed|not upgraded|error" \
  | sed 's/^/    /' || true

INFO "Installing build dependencies…"
run_cmd pkg install -y git build-essential cmake

DEBIAN_FRONTEND=noninteractive apt-get upgrade -y \
  -o Dpkg::Options::="--force-confnew" 2>&1 \
  | grep -E "upgraded|newly|removed|not upgraded|error" \
  | sed 's/^/    /' || true

OK "All packages installed."

# ══════════════════════════════════════════════════════════════════════
#  STEP 5 · CLONE XMRIG
# ══════════════════════════════════════════════════════════════════════
STEP "05  ·  Fetching XMRig Source"

XMRIG_DIR="$HOME/xmrig"
if [[ -d "$XMRIG_DIR" ]]; then
  WARN "Directory ${XMRIG_DIR} already exists — pulling latest commits."
  git -C "$XMRIG_DIR" pull
else
  INFO "Cloning from https://github.com/xmrig/xmrig …"
  git clone --depth 1 https://github.com/xmrig/xmrig.git "$XMRIG_DIR"
fi
OK "Source ready at ${XMRIG_DIR}"

# ══════════════════════════════════════════════════════════════════════
#  STEP 6 · BUILD
# ══════════════════════════════════════════════════════════════════════
STEP "06  ·  Compiling XMRig  (5–20 min on older devices)"

BUILD_DIR="$XMRIG_DIR/build"
mkdir -p "$BUILD_DIR"

INFO "Running cmake…"
cd "$BUILD_DIR" || exit 1
cmake .. -DWITH_HWLOC=OFF 2>&1 | tail -5 | sed 's/^/    /'

INFO "Running make -j${MAKE_JOBS}…"
echo -e "  ${DIM}Keep the screen awake. Do not lock your device.${NC}"
BR

# Progress display
make -j"${MAKE_JOBS}" 2>&1 | while IFS= read -r line; do
  if [[ "$line" =~ ^\[([0-9]+)%\] ]]; then
    PCT="${BASH_REMATCH[1]}"
    FILLED=$(( PCT * 30 / 100 ))
    EMPTY=$(( 30 - FILLED ))
    BAR=""
    for ((i=0;i<FILLED;i++)); do BAR+="█"; done
    for ((i=0;i<EMPTY;i++));  do BAR+="░"; done
    printf "\r  ${LBLUE}[%s]${NC} ${DIM}%3d%%${NC}  " "$BAR" "$PCT"
  fi
done
echo ""

BINARY="$BUILD_DIR/xmrig"
if [[ ! -x "$BINARY" ]]; then
  ERR "Build failed — binary not found at ${BINARY}"
  ERR "Try: cd ~/xmrig/build && make -j4"
  exit 1
fi
OK "Build complete  →  ${BINARY}"

# ══════════════════════════════════════════════════════════════════════
#  STEP 7 · GENERATE LAUNCHERS
# ══════════════════════════════════════════════════════════════════════
STEP "07  ·  Writing Launch Scripts"

# ── mine.sh  (primary launcher)
MINE_SCRIPT="$HOME/mine.sh"
cat > "$MINE_SCRIPT" << LAUNCHER
#!/usr/bin/env bash
# ╔═══════════════════════════════════════════════════╗
# ║  XMRig Launcher  ·  Generated by FutureTonight   ║
# ║  $(date)
# ╚═══════════════════════════════════════════════════╝

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
AUTO_RESTART="$AUTO_RESTART"

# ── colour helpers
C='\033[0;36m'; Y='\033[1;33m'; G='\033[0;32m'; D='\033[2m'; N='\033[0m'

clear
echo -e "\${C}  ┌─────────────────────────────────────────────────────┐\${N}"
echo -e "\${C}  │\${N}  \${Y}⛏  XMRig  ·  FutureTonight Launcher\${N}               \${C}│\${N}"
echo -e "\${C}  └─────────────────────────────────────────────────────┘\${N}"
echo ""
echo -e "  \${D}Pool    \${N}\${Y}\${POOL}\${N}"
echo -e "  \${D}Wallet  \${N}\${Y}\${WALLET:0:20}…\${N}"
echo -e "  \${D}Worker  \${N}\${Y}\${WORKER}\${N}"
echo -e "  \${D}Threads \${N}\${Y}\${THREADS}\${N}  \${D}·  Mode: \${RX_MODE}\${N}"
echo ""

_mine() {
  exec "\${XMRIG}" \\
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
}

if [[ "\${AUTO_RESTART}" == "true" ]]; then
  echo -e "  \${D}Auto-restart enabled. Ctrl+C twice to stop.\${N}"
  echo ""
  while true; do
    _mine
    echo -e "\n  \${Y}⚡ XMRig exited — restarting in 5 s…\${N}"
    sleep 5
  done
else
  _mine
fi
LAUNCHER
chmod +x "$MINE_SCRIPT"
OK "Launcher  →  ${MINE_SCRIPT}"

# ── stop.sh  (convenience stopper)
STOP_SCRIPT="$HOME/stop_mining.sh"
cat > "$STOP_SCRIPT" << 'STOPPER'
#!/usr/bin/env bash
# Stop all xmrig processes
if pkill -f xmrig 2>/dev/null; then
  echo -e "  \033[0;32m▸\033[0m Mining stopped."
else
  echo -e "  \033[2mNo running xmrig process found.\033[0m"
fi
STOPPER
chmod +x "$STOP_SCRIPT"
OK "Stopper   →  ${STOP_SCRIPT}"

# ── status.sh
STATUS_SCRIPT="$HOME/mining_status.sh"
cat > "$STATUS_SCRIPT" << 'STATSCRIPT'
#!/usr/bin/env bash
C='\033[0;36m'; G='\033[0;32m'; R='\033[0;31m'; D='\033[2m'; N='\033[0m'
if pgrep -f xmrig > /dev/null 2>&1; then
  PID=$(pgrep -f xmrig | head -1)
  CPU_USE=$(ps -p "$PID" -o %cpu= 2>/dev/null | xargs)
  MEM_USE=$(ps -p "$PID" -o rss=  2>/dev/null | awk '{printf "%.0f MB", $1/1024}')
  echo -e "${G}  ▸ XMRig is RUNNING${N}  ${D}PID ${PID}${N}"
  echo -e "  ${D}CPU  ${N}${C}${CPU_USE}%${N}   ${D}MEM  ${N}${C}${MEM_USE}${N}"
else
  echo -e "${R}  ✖ XMRig is NOT running.${N}"
fi
STATSCRIPT
chmod +x "$STATUS_SCRIPT"
OK "Status    →  ${STATUS_SCRIPT}"

# ══════════════════════════════════════════════════════════════════════
#  STEP 8 · FINAL SUMMARY
# ══════════════════════════════════════════════════════════════════════
BR
HR
echo -e "  ${GREEN}${BOLD}✔  Setup complete!${NC}  ${DIM}Crafted by ${NC}${ORANGE}${BOLD}FutureTonight${NC}"
HR
BR
echo -e "  ${BOLD}Start mining:${NC}"
echo -e "    ${YELLOW}bash ~/mine.sh${NC}"
BR
echo -e "  ${BOLD}Stop mining:${NC}"
echo -e "    ${YELLOW}bash ~/stop_mining.sh${NC}"
BR
echo -e "  ${BOLD}Check status:${NC}"
echo -e "    ${YELLOW}bash ~/mining_status.sh${NC}"
BR
echo -e "  ${BOLD}Edit config:${NC}"
echo -e "    ${YELLOW}nano ~/mine.sh${NC}"
BR
echo -e "  ${BOLD}Manage wallets:${NC}"
echo -e "    ${YELLOW}cat ~/.xmrig_wallets${NC}"
BR
HR
echo -e "  ${DIM}${BOLD}Android stability tips:${NC}"
echo -e "  ${LGRAY}  ·  Enable 'Acquire Wakelock' in Termux notification bar${NC}"
echo -e "  ${LGRAY}  ·  Disable battery optimisation for Termux in Android Settings${NC}"
echo -e "  ${LGRAY}  ·  Use [${RECOMMENDED_THREADS}/${CPU_CORES}] threads to leave breathing room for Android${NC}"
echo -e "  ${LGRAY}  ·  Lower CPU priority (2–3) to prevent OS kill events${NC}"
HR
BR

if ask_yn "Start mining now?"; then
  bash "$MINE_SCRIPT"
fi