#!/bin/sh

# ANSI Colors
YEL='\033[1;33m'
RED='\033[1;31m'
GRN='\033[1;32m'
CYN='\033[1;36m'
NC='\033[0m'

# === WARNING BANNER WITH CAT ===
printf "${YEL}      |\\__/,|   (\`\\  ${NC}\n"
printf "${YEL}    _.|o o  |_   ) ) ${NC}\n"
printf "${YEL}  -(((---(((-------- ${NC}\n"
printf "${CYN}##################################################${NC}\n"
printf "${CYN}# WARNING: UNOFFICIAL IMPLEMENTATION             #${NC}\n"
printf "${CYN}# This Cloudflare MASQUE client is not an        #${NC}\n"
printf "${CYN}# official product. Stability and longevity      #${NC}\n"
printf "${CYN}# of this method are NOT GUARANTEED.             #${NC}\n"
printf "${CYN}##################################################${NC}\n"

# Settings
DIR="/opt/etc/usque"
URL="https://github.com/Sophiedevops/padavan-cloudflare-masque-client/releases/download/1.0.0/usque"
INI="/opt/etc/init.d/S99usque"
PORT="1090"
SNI="www.google.com"

printf "\n[1/6] Checking resources... "
if [ ! -d "/opt" ]; then printf "${RED}Error: /opt not found${NC}\n"; exit 1; fi
FREE_RAM=$(free -m | awk '/Mem:/ {print $4}')
[ -z "$FREE_RAM" ] && FREE_RAM=$(grep MemFree /proc/meminfo | awk '{print int($2/1024)}')
printf "${GRN}OK (${FREE_RAM}MB)${NC}\n"

# Directory Management
if [ -d "$DIR" ]; then
    printf "\n${CYN}Existing installation found. Choose action:${NC}\n"
    printf "1) Update (Keep config.json)\n"
    printf "2) Clean Install (Delete all)\n"
    printf "q) Abort\n"
    read -p "Your choice: " choice
    case "$choice" in
        1)
            OLD="${DIR}_old_$(date +%s)"
            mv "$DIR" "$OLD"
            mkdir -p "$DIR"
            [ -f "$OLD/config.json" ] && cp "$OLD/config.json" "$DIR/"
            ;;
        2) rm -rf "$DIR"; mkdir -p "$DIR" ;;
        *) exit 0 ;;
    esac
else
    mkdir -p "$DIR"
fi

printf "\n[2/6] Downloading MASQUE core... "
wget -q --no-check-certificate -O "$DIR/usque" "$URL"
[ ! -s "$DIR/usque" ] && { printf "${RED}Download error${NC}\n"; exit 1; }
chmod +x "$DIR/usque"
printf "${GRN}OK${NC}\n"

printf "[3/6] Registering device... "
cd "$DIR" || exit 1
if [ ! -f "config.json" ]; then
    printf "y\n" | ./usque register > reg.log 2>&1
    [ -f "config.json" ] && printf "${GRN}OK${NC}\n" || { printf "${RED}Error${NC}\n"; exit 1; }
else
    printf "${GRN}Config found${NC}\n"
fi

printf "[4/6] Building S99usque service... "
printf "#!/bin/sh\n" > $INI
printf "D=\"$DIR\"\n" >> $INI
printf "P=\"$PORT\"\n" >> $INI
printf "S=\"$SNI\"\n" >> $INI
printf "LOG() { echo \"[\$(date '+%%T')] [\$1] \$2\"; logger -t usque \"\$2\"; }\n" >> $INI
printf "CHECK() { curl --socks5-hostname 127.0.0.1:\$P -m 10 -s https://1.1.1.1/cdn-cgi/trace | grep -q \"warp=on\"; }\n" >> $INI
printf "WDT() {\n  while true; do\n" >> $INI
printf "    T=\$(awk 'BEGIN{srand(); print 180 + int(rand()*361)}')\n" >> $INI
printf "    sleep \$T\n" >> $INI
printf "    if ! CHECK; then LOG \"ERR\" \"Watchdog: Connection lost. Restarting...\"; /opt/etc/init.d/S99usque restart; break; fi\n" >> $INI
printf "  done\n}\n" >> $INI
printf "case \"\$1\" in\n  start)\n    if pidof usque > /dev/null; then exit 0; fi\n" >> $INI
printf "    cd \$D || exit 1\n" >> $INI
printf "    ./usque -c config.json socks -b 0.0.0.0 -p \$P -s \$S -d 1.1.1.1 --dns-timeout 10s > /dev/null 2>&1 &\n" >> $INI
printf "    sleep 10\n" >> $INI
printf "    if ! CHECK; then killall usque 2>/dev/null; sleep 2\n" >> $INI
printf "      ./usque -c config.json socks --http2 -b 0.0.0.0 -p \$P -s \$S -d 1.1.1.1 --dns-timeout 10s > /dev/null 2>&1 &\n" >> $INI
printf "      sleep 15\n    fi\n" >> $INI
printf "    WDT &\n    echo \$! > /tmp/usq.pid\n    ;;\n" >> $INI
printf "  stop)\n    killall usque 2>/dev/null\n" >> $INI
printf "    [ -f /tmp/usq.pid ] && kill \$(cat /tmp/usq.pid) 2>/dev/null\n" >> $INI
printf "    rm -f /tmp/usq.pid\n    ;;\n" >> $INI
printf "  restart) \$0 stop; sleep 2; \$0 start ;;\n" >> $INI
printf "  status) if pidof usque > /dev/null; then echo \"ALIVE\"; else echo \"DEAD\"; fi ;;\n" >> $INI
printf "esac\n" >> $INI
chmod +x $INI
printf "${GRN}OK${NC}\n"

printf "[5/6] Fixing in NVRAM... "
S_SCR="/etc/storage/started_script.sh"
grep -q "$INI start" "$S_SCR" || { printf "\n$INI start\n" >> "$S_SCR"; mtd_storage.sh save >/dev/null 2>&1; }
printf "${GRN}OK${NC}\n"

printf "[6/6] Activating... "
$INI stop >/dev/null 2>&1
$INI start >/dev/null 2>&1
printf "${GRN}Success${NC}\n"

# === FINAL BANNERS ===

# English Version
printf "\n${CYN}==================================================${NC}\n"
printf "${GRN}         SETUP COMPLETED SUCCESSFULLY!${NC}\n"
printf "${CYN}==================================================${NC}\n"
printf "Encryption: ${GRN}X25519MLKEM768 (Kyber)${NC}\n"
printf "Watchdog: ${GRN}Active (Random 3-9 min)${NC}\n\n"
printf "Your ${YEL}cat${NC} is on guard: it sleeps, checks the web,\n"
printf "and switches to TCP if UDP is blocked.\n"
printf "It will keep trying until the connection is restored.\n\n"
printf "${RED}NOTE:${NC} Heavy 4K UHD content (IPTV, Torrents, Streams)\n"
printf "sometimes (not always) may cause 100%% CPU load\n"
printf "and freezes on MT7620A. (YouTube is unaffected\n"
printf "due to chunk buffering).\n\n"
printf "To connect local clients use:\n"
printf "SOCKS5 Proxy: ${GRN}$(nvram get lan_ipaddr):$PORT${NC}\n"
printf "${CYN}==================================================${NC}\n"

# Russian Version (Hex Encoded)
printf "\n${CYN}==================================================${NC}\n"
# ÓÑÒÀÍÎÂÊÀ ÓÑÏÅØÍÎ ÇÀÂÅÐØÅÍÀ!
printf "${GRN}         \xd0\xa3\xd0\xa1\xd0\xa2\xd0\x90\xd0\x9d\xd0\x9e\xd0\x92\xd0\x9a\xd0\x90 \xd0\xa3\xd0\xa1\xd0\x9f\xd0\x95\xd0\xa8\xd0\x9d\xd0\x9e \xd0\x97\xd0\x90\xd0\x92\xd0\x95\xd0\xa0\xd0\xa8\xd0\x95\xd0\x9d\xd0\x90! \xf0\x9f\x8e\x89${NC}\n"
printf "${CYN}==================================================${NC}\n"
# Øèôðîâàíèå / Watchdog
printf "\xd0\xa8\xd0\xb8\xd1\x84\xd1\x80\xd0\xbe\xd0\xb2\xd0\xb0\xd0\xbd\xd0\xb8\xd0\xb5: ${GRN}X25519MLKEM768 (Kyber)${NC}\n"
printf "Watchdog: ${GRN}\xd0\x90\xd0\xba\xd1\x82\xd0\xb8\xd0\xb2\xd0\xb5\xd0\xbd (\xd1\x80\xd0\xb0\xd0\xbd\xd0\xb4\xd0\xbe\xd0\xbc 3-9 \xd0\xbc\xd0\xb8\xd0\xbd)${NC}\n\n"
# Âàø êîòèê íà ñòðàæå
printf "\xd0\x92\xd0\xb0\xd1\x88 ${YEL}\xd0\xba\xd0\xbe\xd1\x82\xd0\xb8\xd0\xba${NC} \xd0\xbd\xd0\xb0 \xd1\x81\xd1\x82\xd1\x80\xd0\xb0\xd0\xb6\xd0\xb5: \xd0\xbe\xd0\xbd \xd0\xb1\xd1\x83\xd0\xb4\xd0\xb5\xd1\x82 \xd0\xbf\xd1\x8b\xd1\x82\xd0\xb0\xd1\x82\xd1\x8c\xd1\x81\xd1\x8f\n"
printf "\xd0\xb2\xd0\xbe\xd1\x81\xd1\x81\xd1\x82\xd0\xb0\xd0\xbd\xd0\xbe\xd0\xb2\xd0\xb8\xd1\x82\xd1\x8c \xd1\x81\xd0\xb2\xd1\x8f\xd0\xb7\xd1\x8c \xd0\xb4\xd0\xbe \xd0\xbf\xd0\xbe\xd0\xb1\xd0\xb5\xd0\xb4\xd0\xbd\xd0\xbe\xd0\xb3\xd0\xbe, \xd0\xb4\xd0\xb0\xd0\xb6\xd0\xb5 \xd0\xb5\xd1\x81\xd0\xbb\xd0\xb8\n"
printf "\xd0\xbf\xd1\x80\xd0\xbe\xd0\xb2\xd0\xb0\xd0\xb9\xd0\xb4\xd0\xb5\xd1\x80 \xd0\xb7\xd0\xb0\xd0\xb1\xd0\xbb\xd0\xbe\xd0\xba\xd0\xb8\xd1\x80\xd0\xbe\xd0\xb2\xd0\xb0\xd0\xbb \xd0\xb2\xd1\x81\xd0\xb5 \xd0\xbf\xd1\x80\xd0\xbe\xd1\x82\xd0\xbe\xd0\xba\xd0\xbe\xd0\xbb\xd1\x8b.\n\n"
# ÂÍÈÌÀÍÈÅ: 4K/IPTV/Torrents
printf "${RED}\xd0\x92\xd0\x9d\xd0\x98\xd0\x9c\xd0\x90\xd0\x9d\xd0\x98\xd0\x95:${NC} \xd0\xa2\xd1\x8f\xd0\xb6\xd0\xb5\xd0\xbb\xd1\x8b\xd0\xb9 4K UHD \xd0\xba\xd0\xbe\xd0\xbd\xd1\x82\xd0\xb5\xd0\xbd\xd1\x82 (IPTV, \xd1\x82\xd0\xbe\xd1\x80\xd1\x80\xd0\xb5\xd0\xbd\xd1\x82\xd1\x8b)\n"
printf "\xd0\xb8\xd0\xbd\xd0\xbe\xd0\xb3\xd0\xb4\xd0\xb0 (\xd0\xbd\xd0\xb5 \xd0\xbe\xd0\xb1\xd1\x8f\xd0\xb7\xd0\xb0\xd1\x82\xd0\xb5\xd0\xbb\xd1\x8c\xd0\xbd\xd0\xbe) \xd0\xbc\xd0\xbe\xd0\xb6\xd0\xb5\xd1\x82 \xd0\xb2\xd1\x8b\xd0\xb7\xd1\x8b\xd0\xb2\xd0\xb0\xd1\x82\xd1\x8c \xf0\x9f\x92\xa5 100%% \xd0\xbd\xd0\xb0\xd0\xb3\xd1\x80\xd1\x83\xd0\xb7\xd0\xba\xd1\x83 CPU\n"
printf "\xd0\xb8 \xd1\x84\xd1\x80\xd0\xb8\xd0\xb7\xd1\x8b \xd0\xbd\xd0\xb0 MT7620A. (\xd0\x94\xd0\xbb\xd1\x8f YouTube \xd1\x8d\xd1\x82\xd0\xbe \xd0\xbd\xd0\xb5 \xd0\xbf\xd1\x80\xd0\xbe\xd0\xb1\xd0\xbb\xd0\xb5\xd0\xbc\xd0\xb0\n"
printf "\xd0\xb1\xd0\xbb\xd0\xb0\xd0\xb3\xd0\xbe\xd0\xb4\xd0\xb0\xd1\x80\xd1\x8f \xd0\xb1\xd1\x83\xd1\x84\xd0\xb5\xd1\x80\xd0\xb8\xd0\xb7\xd0\xb0\xd1\x86\xd0\xb8\xd0\xb8).\n\n"
# Ïîäêëþ÷åíèå èç ëîêàëüíîé ñåòè:
printf "\xd0\x94\xd0\xbb\xd1\x8f \xd0\xbf\xd0\xbe\xd0\xb4\xd0\xba\xd0\xbb\xd1\x8e\xd1\x87\xd0\xb5\xd0\xbd\xd0\xb8\xd1\x8f \xd0\xba\xd0\xbb\xd0\xb8\xd0\xb5\xd0\xbd\xd1\x82\xd0\xbe\xd0\xb2 \xd0\xb8\xd0\xb7 \xd0\xbb\xd0\xbe\xd0\xba\xd0\xb0\xd0\xbb\xd1\x8c\xd0\xbd\xd0\xbe\xd0\xb9 \xd1\x81\xd0\xb5\xd1\x82\xd0\xb8 \xd0\xb8\xd1\x81\xd0\xbf\xd0\xbe\xd0\xbb\xd1\x8c\xd0\xb7\xd0\xbe\xd0\xb2\xd0\xb0\xd1\x82\xd1\x8c:\n"
printf "SOCKS5 \xd0\x9f\xd1\x80\xd0\xbe\xd0\xba\xd1\x81\xd0\xb8: ${GRN}$(nvram get lan_ipaddr):$PORT${NC}\n"
printf "${CYN}==================================================${NC}\n"
