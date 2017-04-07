OH_SETUP_CMD=${0##*/} 
OH_PATH="$0"
OH_SETUP_CMD=${OH_PATH##*/}
OH_ROOT_DIR=${OH_PATH%/*}
OH_SCRIPT_NAME="${OH_ROOT_DIR}/hofersetup.sh"
echo "$0 : checkiing main script existence $OH_SCRIPT_NAME..."
[ -f "$OH_SCRIPT_NAME" ] && echo "install from $OH_ROOT_DIR" || exit 1

sh "$OH_SCRIPT_NAME"  \
--install-cmd="--prefix=/usr --etc=/etc --reinstall"  \
--setup-dir=lesjfkmac \
--vars=vars.lesjfkmac \
--wget-cmd="/usr/bin/wget --no-check-certificate" \
--rsa-git="https://codeload.github.com/OpenVPN/easy-rsa/zip/master" \
--cn-server=lesjfkmac.ddns.net \
--cn-client=vpn1.ddns.net \
--ssl-cmd="/usr/bin/openssl" \
--digest=md5 \
--days=180 \
--keysize=1024 \
--req-cn="lesjfkmac"  \
--req-cc="FR" \
--req-st="Ile de France" \
--req-city="Saint Gratien" \
--req-org="MCS-Lesjfkmac" \
--req-email="lesjfkmac@gmail.com" \
--req-ou="My Organizational Unit" \
--vpn-dns=lesjfkmac.ddns.net:1194 \
"$@"
