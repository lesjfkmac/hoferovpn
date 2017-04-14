#!/bin/sh
# ovpnhost install script
#
#. Common variables Directory and sub directories  structure.
#

OH_SETUP_CMD=${0##*/} 
OH_SCRIPT_NAME="hofer"
OH_ROOT_DIR=""  #"$(dirname "$(readlink -f  "$0")")"
absPath() {
    local opwd="$(pwd -P)" ret=""
    if [[ -d "$1" ]]; then
        cd "$1"
        ret="$(pwd -P)"
    else 
        cd "$(dirname "$1")"
        ret="$(pwd -P)/$(basename "$1")"
    fi
    cd "$opwd"
    echo "$ret"
}

OH_PATH="$(absPath "$0")"
OH_SETUP_CMD="${OH_PATH##*/}"
OH_SETUP_PATH="$(dirname "$OH_PATH")"
OH_ROOT_DIR="$(pwd -P)"

OH_BOOT_DIR="/ovpn_bootstrap"
OH_BOOT_CMD=$OH_BOOT_DIR".sh"
OH_BOOT_INSTALL="/ovpn_install.sh"
#
OH_HOST_DIR="/ovpnhost"
OH_VPN_DIR="/openvpn"

# Wrapper around printf - clobber print since it's not POSIX anyway
print() { printf "%s\n" "$*" ; }
failed () { print ": failed ($1) - exiting..." ;	exit 1 ; }
passed () { [ $# -eq 0 ] && printf "%s\n" "...passed" ||  printf "%s"  "$*" ; }
msg() { printf "%s" "$OH_SCRIPT_NAME $*" ; }
pmsg() { printf "%s\n" "$OH_SCRIPT_NAME $*" ; }

## end of common install and setup declares


#
#<!BEGIN-BOOT> donot remove this label begin delimiter for build bootstrap script
#
ETC_REINSTALL=0
ETC_VPN_NAME=""
ETC_PREFIX=""
ETC_RM_FILES="yes"
ETC_DIR="/etc"
ETC_ALT_DIR=""
ETC_INITD_DIR="/init.d"
ETC_VPN_DIR=$OH_VPN_DIR
ETC_HOST_DIR=$OH_HOST_DIR
ETC_SETUP_DIR=$OH_ROOT_DIR


install_exec_setup () {
    local item= version= etcd="/etc" initd="/init.d"
    pmsg "Working directory $( pwd -P)"
    [ ${#ETC_VPN_NAME} -eq 0 ]  && failed "vpn name not specified"
    msg "checking root user privileges" ; [ $(whoami) != "root" ] && failed "please run as root" || passed

    item="$ETC_SETUP_DIR"
    msg "setup files $item" ;   [ ! -d $item ] && failed "not found " || passed 

    item=$ETC_PREFIX"/sbin/openvpn" 
    [ -f $item ] && version=$($item --version 2>/dev/null | head -n 1) || failed "module $item not found"
    pmsg "$version" 

    item=$ETC_PREFIX"/bin/openssl" 
    [ -f $item ] && version=$($item version 2>/dev/null | head -n 1) || failed "module $item not found"
    pmsg "$version" 

    item=$ETC_DIR$ETC_VPN_DIR
    msg "configuration file $item" 
    if [ ! -d $item ] ; then
	passed " not found in $etcd trying prefix" 
	ETC_DIR=$ETC_PREFIX$etcd
	item=$ETC_DIR$ETC_VPN_DIR
	[ ! -d $item ] && failed "$ item not found" || passed
    else
	passed
    fi
    ETC_INITD_DIR=$ETC_DIR$initd

    item=$( find $ETC_INITD_DIR -type f  -name "*${ETC_VPN_DIR##/}")
    msg "init scripts $item" ; [ ! -f $item ]  && failed " not found" || passed
    OVPN_CMD="$item"

    msg "script attributes $item" 
    if [ ! -x $item ]  ; then
	passed "noexec - fixing attributes-"
	#ls -l $item
	chmod 'u+x' $item
	passed "rc"$?"..."
    fi
    [ ! -x $item ] &&  failed "noexec" || passed

    msg "host vpn $ETC_VPN_NAME installation status "
    if  [  -e $ETC_DIR$ETC_VPN_DIR"/"$ETC_VPN_NAME".conf" ] ; then
	passed "already setup" 
	[  $ETC_REINSTALL -eq 0 ] &&  failed " --reinstall option not specified" || passed
	case  "$($item status $ETC_VPN_NAME)" in
	    *"not running"*) pmsg "vpn stopped" ;;
	    *"running.") pmsg  "vpn stopping"  ; $item stop $VPN_NAME ;;
	    *) item="$($item status $ETC_VPN_NAME)" ; pmsg "Warning running  status unknown: $item" ;;
	esac
    else
	passed
    fi

    if [ ${#ETC_ALT_DIR} -gt 0 ] ; then
	msg "etc alternate directory $ETC_ALT_DIR " 
	if [ -d $ETC_ALT_DIR ] ; then
	    rm -rf $ETC_ALT_DIR$OH_HOST_DIR 
	    passed " (reset) "
	fi
	mkdir -p $ETC_ALT_DIR
	mkdir $ETC_ALT_DIR$ETC_HOST_DIR
	passed
    else
	ETC_ALT_DIR=$ETC_DIR
    fi

    msg "install ${OH_HOST_DIR##*/} setup files and keys"
    cp  -Rf $ETC_SETUP_DIR$OH_HOST_DIR"/"  $ETC_ALT_DIR"/"
    [ $? -ne 0 ]  && failed "xcopy" || passed
    [ ! -d $ETC_ALT_DIR$ETC_VPN_DIR ] && mkdir $ETC_ALT_DIR$ETC_VPN_DIR

    msg "install initscript symlink to  $ETC_VPN_NAME conf file"
    rm -f $ETC_ALT_DIR$ETC_VPN_DIR"/"$ETC_VPN_NAME".conf"
    ln -s ".."$OH_HOST_DIR"/server.conf" $ETC_ALT_DIR$ETC_VPN_DIR"/"$ETC_VPN_NAME".conf"  
    [ $? -ne 0 ] && failed "symlink" || passed

    msg "security rules for keys"
    chmod -R 600 $ETC_ALT_DIR$OH_HOST_DIR"/keys"
    [ $? -ne 0 ] && failed "chmod " || passed " - up/script"
    chmod +x $ETC_ALT_DIR$OH_HOST_DIR"/server.up"
    [ $? -ne 0 ] && failed "chmod " || passed

    item=$ETC_INITD_DIR$ETC_VPN_DIR
    item=$OVPN_CMD
    $item start $ETC_VPN_NAME
    pmsg "start host ovpn deamon"
    case    "$($item status $ETC_VPN_NAME)" in
	*"running.")  pmsg "vpn successfully started"  ;;
	*) pmsg "vpn failed to start -check logs" ;;
    esac

    exit 0
}


help_install () { 
    help_install_usage
    help_install_options
}

help_install_usage () {
    print  "
Running in Bootstrap mode
Usage: ./$OH_SETUP_CMD options
"
}
help_install_options () {
    print "
Options are the following 
--vpn=NAME - openvpn configuration file name  (mandatory)
--prefix=NAME - Openvpn and OpenSSL install prefix for bin files (default to '')
--etc=PATH - installation path for SETUP files (default to /prefix/etc)
--reinstall - reinstall switch to overide existing settings
--rm-files-off - disable auto remote of installation files 
"
}

install_decode_opts () {
    local opt= val= txt= hdr="general"
    [ ! -n "$1" ]  && help_install
    while [ -n "$1"  ] ; do
	opt="${1%%=*}" ; val="${1#*=}"
	case $opt in
	    -vpn|--vpn) ETC_VPN_NAME="$val"  ; txt="(vpn.conf name)" ;;
	    -etc|--etc) ETC_ALT_DIR="$val"   ; txt="(alternate config directory)" ;;
	    -prefix|--prefix) ETC_PREFIX="$val"   ; txt="(prefix for open-product)" ;;
	    --reinstall|-reinstall) ETC_REINSTALL=1   ; txt="(allow override)" ;;
	    -x|--x) set -x ; passed "(activate debug mode)"  ;;
	    --setup-dir) ETC_SETUP_DIR="$val" ; txt="(build directory)" ;;
	    --rm-files-off) ETC_RM_FILES="no" ; txt="(disable autoremove)" ;;
	    -*) failed "invalid $opt install options -see help" ;;
	    "<none>"|boot|install) hdr="$opt cli overrides -" ; txt="" ;;
	    *) pmsg "$hdr option parsing complete with ($opt) cli-cmd" ; break  ;;
	esac
	[ ${#txt} -ne 0 ] && pmsg  "$hdr option $opt set to $val - $txt ...passed" 
	shift 1
    done
}

install_main () {
    install_decode_opts $@
    install_exec_setup
    exit 0
}

[ "$OH_SETUP_CMD" == "${OH_BOOT_INSTALL##*/}" ]  && install_main "$@"
#
#<!END-BOOT> donot remove this label -end delimiter for build bootstrap script



OH_BUILD=0
OH_PREFIX=0
OH_REINSTALL=0
OH_REKEYGEN=0
OH_REKEY_SERVER=0
OH_REKEY_CLIENT=0
OH_REKEY_DH=0
OH_RESETDIR=0
OH_EXISTDIR=0
OH_WARNDIR=0
#
OH_GIT_EASYRSA="https://codeload.github.com/OpenVPN/easy-rsa/zip/master"
OH_GIT_MASTER='/master'
OH_GIT_SRCSDIR='*/easyrsa3/'

OH_HEAD="/hdrovpn"
OH_NAME=""
OH_CLIENT=""
OH_SERVER=""
OH_VPN_D="vpnhost.ddns.net"
OH_VPN_P=1194
OH_WGET_CMD="wget"
OH_INSTALL_CMD=""
#
#. Directory and sub directories  structure.
#

OH_SETUP_DIR="" # $OH_ROOT_DIR"/ovpn_setup"
OH_ROOT_SUBDIRS="$OH_SETUP_DIR"

#OH_HOST_DIR="/ovpnhost"
#OH_VPN_DIR="/openvpn"
OH_GIT_DIR="/easyrsa3"
OH_RSA_DIR="/easyrsa"
OH_SETUP_SUBDIRS="$OH_HOST_DIR $OH_VPN_DIR  $OH_GIT_DIR  $OH_RSA_DIR"

OH_PROFILE=$OH_RSA_DIR'/profile'
OH_TEMPLATE=$OH_RSA_DIR'/template'
OH_PKI_DIR=$OH_RSA_DIR'/pki' 
OH_X509_DIR=$OH_RSA_DIR'/x509-types'
OH_RSA_SUBDIRS="$OH_PROFILE $OH_TEMPLATE $OH_PKI_DIR $OH_X509_DIR"

OH_JAIL_DIR=$OH_HOST_DIR'/jail'
OH_KEYS=$OH_HOST_DIR'/keys'
OH_HOST_SUBDIRS="$OH_JAIL_DIR $OH_KEYS"

OH_CCD=$OH_JAIL_DIR'/ccd'
OH_JAIL_SUBDIRS="$OH_CCD"


EASYRSA="/easyrsa"
OPENSSL="/openssl*.cnf"
VARSRSA="/vars.example"
USERVARS="/vars."
X509TYPE="/x509-types"

PKI_CERT_DIR=$OH_PKI_DIR"/certs_by_serial"
PKI_CRT=$OH_PKI_DIR"/issued"
PKI_KEY=$OH_PKI_DIR"/private"
PKI_REQ=$OH_PKI_DIR"/reqs"
PKI_SUBDIRS="$PKI_CERT_DIR $PKI_CRT $PKI_KEY $PKI_REQ"

EASYRSA_DIGEST=
EASYRSA_SSL_CMD=
EASYRSA_KEY_SIZE=  
EASYRSA_REQ_COUNTRY= 
EASYRSA_REQ_PROVINCE= 
EASYRSA_REQ_CITY= 
EASYRSA_REQ_ORG=  
EASYRSA_REQ_EMAIL= 
EASYRSA_REQ_OU= 
EASYRSA_REQ_CN=
EASYRSA_CRL_DAYS=

checking () { msg "${OH_VPN_DIR##*/}" "$*" ; }
installing () { msg "$OH_NAME" "$*" ; }
building () { msg "${OH_RSA_DIR##*/}" "$*" ; }

help_boot () { 
    help_boot_usage
    help_install_options
}

help_boot_usage () {
    print  "
Generating  Bootstrap and install time default command line options
Usage: ./$OH_SETUP_CMD gen-bootstrap options
"
}

build_bootstrap () {
    local item="$OH_SETUP_DIR"  sdir=  cmd="$1" rmauto="yes"
    local item_b=$OH_SETUP_DIR$OH_BOOT_DIR

    pmsg "gen-bootstrap install cli default settings"
    install_decode_opts $@  
    [ -n $ETC_RM_FILES ] && rmauto=$ETC_RM_FILES 
    
    pmsg "gen-bootstrap setup build directory ${OH_BOOT_DIR##*/}"
    OH_WARNDIR=0 ; OH_EXISTDIR=0 ; OH_RESETDIR=1
    build_subdirs "$item"  "$OH_BOOT_DIR"
    
    
    local item="$item_b$OH_HEAD"
    local item_hdr=$item".hdr" 
    local item_tar=$item".tar"
    printf "#!/bin/sh
BS=
CMD=\"$cmd \$@\" ; RM_OFF=\"$rmauto\"" > "$item"
    printf '
echo "ovpn_bootstrap Host Openvpn Full EasyRsa SETUP - extracting archive... please wait"
mkdir bootstrap
dd if=$0 bs=$BS skip=1 | tar xz -C  bootstrap
cd bootstrap && sh ovpn_install.sh "$CMD" && cd .. && [ "$RM_OFF" == "yes" ] && rm -rf bootstrap
exec /bin/sh --login\n' >> "$item"

    msg "gen-bootstrap building autoextract script" ; [ ! -f $item ]  && failed "$item not saved" || passed

    local bs_len=$(ls -la $item | awk '{ print $5}') 
    local bs="BS="$(($bs_len + ${#bs_len} ))
    
    msg "gen-bootstrap computing autoextract header script size -"
    sed -e "/BS=/ s/BS=/$bs/" < $item >  $item_hdr
    [ $? -ne 0 ] && failed "cp/sed $item $item_hdr" 

    bs_len=$(ls -la $item_hdr | awk '{ print $5 } ')
    local bs2="BS="$(($bs_len + 0 ))
    [ "$bs" != "$bs2" ]  && failed "script size computed [$bs] and found [$bs2] mismatched"  
    passed " set to $bs" ; passed 
    
    msg "gen-bootstrap building archive file from ${OH_HOST_DIR##*/} conf directory"
    #cp "$OH_ROOT_DIR/$OH_SETUP_CMD" "$OH_SETUP_DIR$OH_BOOT_CMD.full"
    awk 'NR==1,/<!END-BOOT>/ { print $0 }'  "$OH_ROOT_DIR/$OH_SETUP_CMD" >  "$OH_SETUP_DIR$OH_BOOT_INSTALL"
    tar -czf $item_tar  -C "$OH_SETUP_DIR"  "${OH_HOST_DIR##*/}" "${OH_BOOT_INSTALL##*/}"
    [ $? -ne 0 ] && failed "tar-czf build $item_tar" || passed
    rm  -f "$OH_SETUP_DIR$OH_BOOT_INSTALL"

    msg "gen-bootstrap merging autoextract and install scripts and archive setup files"
    cat $item_hdr  $item_tar > "$OH_SETUP_DIR$OH_BOOT_DIR$OH_BOOT_CMD"
    [ $? -ne 0 ] && failed "cat merge $item_hdr $item_tar" || passed
    
    msg "gen-bootstrap removing temporary intermediate files"
    rm -f $item_hdr $item_tar  $item
    [ $? -ne 0 ] && failed "remove" || passed
    
    msg "gen-bootstrap saving bootstrap script ${OH_BOOT_CMD##*/} in setup dir"
    mv "$OH_SETUP_DIR$OH_BOOT_DIR$OH_BOOT_CMD"  "$OH_SETUP_DIR"
    [ ! -f "$OH_SETUP_DIR$OH_BOOT_CMD" ]  && failed "copy" || passed
    rm -rf  "$OH_SETUP_DIR$OH_BOOT_DIR"
    echo $OH_SETUP_DIR
    ls -l $OH_SETUP_DIR
}


help_options() {
    print "
$OH_SCRIPT_NAME: $OH_SETUP_CMD-Host-Ovpn-Easy-RSA Global Option Flags

The following options may be provided before the command. Options specified
at runtime override env-vars and any 'vars' file in use. Unless noted,
non-empty values to options are mandatory.

General  $OH_SETUP_CMD-Ovpn options :

--rsa-git=URL   : declares the easy-rsa github download url.
--setup-dir=DIR    : declares the build root directory.
--vpn-dns=DNS:PORT  : declares the url ovpn domain server name and port Number.
--cn-server=NAME : declares the host server and CA CN name (default to --setup-dir).
--cn-client=NAME : declares a client and CA name (default to 'vpn1' ).

General options Easy-RSA:

--vars=FILE     : define a specific 'vars' file to use for MyWdmCloud-Ovpn-Easy-RSA config

Certificate & Request options: (these impact cert/req field values)

--days=#        : sets the signing validity to the specified number of days
--keysize=#     : size in bits of keypair to generate
--req-cn=NAME   : default CN to use
--digest=NAME   : overide default algo sha256 | md5
--ssl-cmd=NAME  : 0verride openssl command and options openssl | opt/bin/openssl
--wget-cmd=NAME : Override wget command and options 

Organizational DN options: (only used with the 'org' DN mode)
(values may be blank for org DN options)

--req-cc=CC        : country code (2-letters)
--req-st=NAME     : State/Province
--req-city=NAME   : City/Locality
--req-org=NAME    : Organization
--req-email=NAME  : Email addresses
--req-ou=NAME     : Organizational Unit

Installation SETUP default options for bootstrap generation  and install rutile
--install-cmd=LIST : string delimited list of install options
"
} 

help_usage() {
    # command help:
    print "
$OH_SCRIPT_NAME: $OH_SETUP_CMD-Ovpn-Easy-RSA usage and overview

USAGE: $OH_SETUP_CMD [options] COMMAND [command-options]

A list of commands is shown below. To get detailed usage and help for a
command, run:
./$OH_SETUP_CMD help COMMAND

For a listing of options that can be supplied before the command, use:
./$OH_SETUP_CMD help options

Here is the list of commands available with a short syntax reminder. Use the
'help' command above to get full usage details.

build  [ cmd [opts ] [ cmd ] ... ]]]
build-full   [ cmd-opts ]

build-server-full   [ cmd-opts ]
build-client-full   [ cmd-opts ]

gen-dh
build-ca

init-vars   [ cmd-opts ]		
init-pki|clean-all  

''|help|-h|--help|--usage [ cmd-opts ]
"		
} # => ()

# Detailed command help
# When called with no args, calls usage(), otherwise shows help for a command
cmd_help() {
    [ ! -n "$1" ] && help_usage
    while [ -n "$1" ] ; do
	case "$1" in
	    init-pki|clean-all) help_init_pki ;;
	    init-vars) help_init_vars ;;
	    build-ca) help_build_ca ;;
	    build-server-full) help_build_server_full ;;      
	    build-client-full) help_client_full ;;
	    gen-dh) help_gen_dh ;;
	    build-full) help_build_full ; help_cn_names ;;
            cn-names) help_cn_names ; help_server_full ; help_client_full ;;
	    options) help_options ;; 
	    gen-bootstrap) help_boot ;;
	    install) help_install ;;
	    usage) help_usage ;;
	    help) help_usage ; help_options ; help_boot ; help_install ;help_init_vars ; help_build_cli ;; 
	    build) help_build_cli ;;
	    *) help_unknown "$1" ; failed ;;
	esac
	shift
    done
}


help_init_pki () {
    print '
init-pki 
Removes & re-initializes the PKI dir for a clean PKI
' 
}

help_init_vars () {
    print '
init-vars [ [cmd-opts[=FILE1] ][cmd-opts[=FILE2]] -q ]
Manage PKI user variable setting file --vars
'
    print '
-s|-save - save all PKI variables in the setup  --vars file (default or FILE1 if specified) for Easyrsa
-d|-delete - remove the specified --vars file (default or FILE1 if specified)
-e|-status - (default) display the current active --vars file within potential hierarchy of --vars files
-r|-replace - replace  the --vars file 
-l|-load - set all variables to --vars file values
-q|-quit - ends the parsing of help commands.
'
}


help_dirs () {
    print '
dirs [ cmd-opts [ cmd-opts [ cmd-opts ]]] [-xeq]
Manage the hofersetup directories and sub-directories
'
    print '
-w|-warn -  Check the status of each dir and sub-dirs issue warnings for incosistencies 
-b|-build  - enter build mode. All Directories will be recreated 
-r|-reinstall - enter reinstall mode. Directory will be recreated of needed 
-z|reset  - enter reset mode. Directory will be reset 
-e|-exist - enter exist mode. Use directory and abort if not usable 
-xeq - exit sub-command. Ends the current dirs command. 
'
} 

help_cn_names () {
    print '
-c|-client - assign a client CN name for key generation
-s|-server - assign a server CN name for key generation
-dh - regenerate the DH keys
-ca) - regenerate a certificate  CA CN for keys pairs 
-q|-end - exit the parsing mode
'
}

help_build_ca () {
    print '
build-ca 
Creates a new CA
'
}

help_build_server_full () {
    print '
build-server-full [ cmd-opts ]
(Re)Generate a RSA key pair and sign-it and (re)build the OVPN server configuration files
'
    print '
cmd-opts - server CN name if specified (default to --cn-server)  for Easyrsa and OVPN
' 
}

help_client_full () {
    print '
build-client-full [ cmd-opts ]
(Re)Generate a RSA key pair and sign-it and (re)build the OVPN client configuration files
'
    print '
cmd-opts - client CN name if specified (default to --cn-client)  for Easyrsa and OVPN' 
}


help_gen_dh () {
    print '
gen-dh
Generates DH (Diffie-Hellman) 
'
}

help_build_full () {
    print '
build-full  [NAME1 [ NAME2 ]]

(Re)build  and re-initializes the whole Easyrsa and Ovpn server and client configuration and setups files'
    print '
NAME1 - declares the server CN name to use (default to --cn-server).
NAME1 NAME2 - declares the server and client CN names to use (default to --cn-server and --cn-client) .' 
}

help_build_cli () {
    print "
build [cmd-list and options ]

$OH_SETUP_CMD - build cli interface 
build-cmd cli manual execution of basic fonctions/routines

dirs COMMAND - check/init/reset the existence of the the whole set of directories and sub-directories
git - reinstall the EASYRSA scripts from the GIT source
vars COMMAND [ NAME1 [ NAME2 ]] -q|vars - enter cli mode to manage vars files
rsa - setup the Easyrsa OpenSSL rsa environment 
cn-names  COMMAND - setup CN names and key regen switches 
pki | pkib  - display or rebuild the pki environment and generate CN certificates 
ovpn-templates - rebuild the template SETUP and conf files for OpenSSL openvon easysrsa 
ovpn - rebuild the server and client configuration and profile files
"
    print "
build-cmd cli interface : manual execution of composite functions 

init == ' dirs git rsa' - generate  the basic environnement 
var == ' vars load VARS.LOCAL vars save VARS.FILE -q' - setup local easyrsa vars
full == ' init var pki ovpn CN-SERVER CN-CLIENT' - generate the full environment and CN certificates 
"
    print "
build-cmd cli interface : bootstrap generation and local installation after succesful 'build full'

boot - generate an auto-extract bootstrap script for the current vpn
install - direct auto install of the current vpn on this machine
"
}

help_unknown () {
    print "
Unknown command: $1 (try without commands for a list of commands)
"
} 


build_subdirs () {
    local msg="Sub-Dirs"  tdir="$1"  dirs="$2"  opt="$3"
    local check_dirs=""  check_hdr=" checked:"
    local reset_dirs=""  reset_hdr=" reset:"
    local build_dirs="" build_hdr=" created:"
    local warn_dirs=""  warn_hdr=" missing:"
    local item= sdirn= sdir= 

    for item in $dirs ; do
	sdirn=${item##*/}
	sdir=$tdir$item
	if [ $OH_EXISTDIR -eq 1 ] ; then
	    check_dirs=$check_dirs" - "$sdirn	
	    [ ! -d $sdir  ] && failed " $1 $sdirn - mkdir $sdir"  
	else
	    if [ -d $sdir  ] ; then
		if [ $OH_RESETDIR -eq 1 ] ; then
		    reset_dirs=$reset_dirs" - "$sdirn
		    rm -rf $sdir ; mkdir $sdir
		    [ $? -gt 0 ] && failed " $1 $sdirn - rm mkdir $sdir"
		else
		    check_dirs=$check_dirs" - "$sdirn
		fi
	    else
		if [ $OH_WARNDIR -eq 1 ] ; then
		    warn_dirs=$warn_dirs" - "$sdirn
		else
		    build_dirs=$build_dirs" - "$sdirn
		    mkdir  $sdir
		    [ $? -gt 0 ] && failed " $1 $sdirn - mkdir $sdir"
		fi
	    fi
	fi
    done
    item=${tdir##*/}${item%*/*}
    [ ${#check_dirs} -gt  1 ] && pmsg "$msg$check_hdr$item$check_dirs" 
    [ ${#reset_dirs} -gt 1 ] && pmsg "$msg$reset_hdr$item$reset_dirs" 
    [ ${#build_dirs} -gt 1 ] && pmsg "$msg$build_hdr$item$build_dirs" 
    [ ${#warn_dirs} -gt 1 ] && pmsg "$msg$warn_hdr$item$warn_dirs" 
}       

setup_ovpn () {
    local opt="$1"  tserver="/server" tclient="/client"  tup=".up"   tconf=".conf"   tovpn=".ovpn"   
    local ca_crt='/ca.crt' tcrt=".crt"  tkey=".key" 

    if [ $OH_RESETDIR  -eq 1 ] ; then      
	pmsg "making server and client templates $OH_TEMPLATE"

	cat > "$OH_SETUP_DIR$OH_TEMPLATE$tclient$tconf" << END
#
# OpenVPN configuration file for
# home using SSL/TLS mode and RSA certificates/keys.
# configuration file generated by $OH_SCRIPT_NAME - $OH_SETUP_CMD
# 
END
	cat >> "$OH_SETUP_DIR$OH_TEMPLATE$tclient$tconf" << 'END'
# Use a dynamic tun device.
dev tun

# Our OpenVPN peer is the office gateway.
remote <server_dnsname_port> 

# In SSL/TLS key exchange, Home client role.
tls-client

# LZO compression
comp-lzo

resolv-retry infinite
nobind
persist-tun
persist-key

# Verbosity level.
verb 3
END

	cat > "$OH_SETUP_DIR$OH_TEMPLATE$tclient$tup" << 'END'
ifconfig-push 192.168.2.11  192.168.2.10
END

	cat > "$OH_SETUP_DIR$OH_TEMPLATE$tserver$tconf" << END
# 
# configuration file generated by $OH_SCRIPT_NAME - $OH_SETUP_CMD
# Sample OpenVPN configuration file for
# office using SSL/TLS mode and RSA certificates/keys.
#
END
	cat >> "$OH_SETUP_DIR$OH_TEMPLATE$tserver$tconf" << 'END'
# Use a dynamic tun device.
dev tun1

mode server
# Choose an uncommon local subnet for the virtual VPN end points.
ifconfig 192.168.2.10 192.168.2.11
# Our up script will establish routes once the VPN is alive.
# Running scripts need the script-security set to 2.
script-security 2
up <path>/../server.up

# Push the 'server subnet route' to the clients
push "route 192.168.1.0 255.255.255.0"
push "redirect-gateway def1"
# Push the WINS server to the clients - if we have a Samba WINS server.
; push "dhcp-option WINS 192.168.1.77"
# define the client network
client-config-dir ccd
route 192.168.2.0 255.255.255.0
push "dhcp-option DNS 192.168.1.1"

# In SSL/TLS key exchange, Office will assume server role 
tls-server
# Diffie-Hellman Parameters (tls-server only)
dh  <path>/dh.pem

# Certificate Authority
ca  <path>/ca.crt

# Our certificate/public key
cert  <path>/<server_cn>.crt

# Our private key
key  <path>/<server_cn>.key

# OpenVPN 2.0 uses UDP port 1194 by default
port <server_port>
proto udp

# Downgrade UID and GID to nobody" after initialization for extra security.
user nobody
group share

# LZO compression
comp-lzo

persist-tun
persist-key

# Verbosity level.
verb 3

# Log files
log /var/log/ovpnhost.log

# Write OpenVPN's main process ID to file.
#writepid /tmp/ovpnhostpid.out

#  Inactivity timeout
; inactive            45
keepalive 10 60

chroot ../ovpnhost/jail

END

	cat > "$OH_SETUP_DIR$OH_TEMPLATE$tserver$tup" << 'END'
#!/bin/sh
IPFORWARD='/proc/sys/net/ipv4/ip_forward'
IPF=$(cat $IPFORWARD)
VPN=<server_cn>
opt="/opt/sbin/"
iptables="iptables"
[ -x "$opt$iptables" ] && iptables="$opt$iptables"

#route add -net 192.168.2.0  gw $5 netmask 255.255.255.0
#echo "openvpn server startup default route added for tun vlan"

echo -n "$VPN : openvpn server startup Ipforwarding ($IPF) "
[ 0 -eq  $IPF  ]  &&  echo " switched on" || echo "already setup"
echo 1 > "$IPFORWARD"

$iptables -t nat -F POSTROUTING
$iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
#
END
    fi

    if [ $OH_REINSTALL -eq 1 -o $OH_REKEY_CLIENT -eq 1 ] ; then
	building "generating setup  client ovpn profile - $OH_CLIENT$tovpn:"
        for suf in  $tcrt $tkey  ; do
           [ $suf == $tcrt ] && item=$OH_SETUP_DIR$PKI_CRT"/"$OH_CLIENT$suf
           [ $suf == $tkey ] && item=$OH_SETUP_DIR$PKI_KEY"/"$OH_CLIENT$suf
           [ -f "$item" ] && cp "$item" "$OH_SETUP_DIR$OH_KEYS" || failed "missing key files $item"
	   [ $? -gt 0 ] && failed "copy key to $OH_SETUP_DIR$OH_KEYS" || passed " ($suf)"
        done
        passed

	building "generating CCD setup $tovpn client up file $OH_CLIENT"
	cp -f   $OH_SETUP_DIR$OH_TEMPLATE$tclient$tup   $OH_SETUP_DIR$OH_CCD"/"$OH_CLIENT
	[ $? -gt 0 ] && failed "copy $tclient$tup to $OH_SETUP_DIR$OH_CCD" || passed
	local item=$OH_SETUP_DIR$OH_PROFILE"/"$OH_CLIENT$tovpn
	cat > $item  << END
# <begin> generated by $0
`cat $OH_SETUP_DIR$OH_TEMPLATE$tclient$tconf`

<ca>
`cat $OH_SETUP_DIR$OH_KEYS$ca_crt`
</ca>

<cert>
`sed -n '/BEGIN/,$p' $OH_SETUP_DIR$OH_KEYS"/"$OH_CLIENT$tcrt`
</cert>

<key>
`cat $OH_SETUP_DIR$OH_KEYS"/"$OH_CLIENT$tkey`
</key>
# <end> generated by $0
END
	building "formating DNS/Port settings - $OH_VPN_D with port $OH_VPN_P"
	sed -i "s%<server_dnsname_port>%$OH_VPN_D $OH_VPN_P%g "  $item
	[ $? -gt 0 ] && failed " sed $item url"  ||  passed
    fi

    if [ $OH_REINSTALL -eq 1  -o  $OH_REKEY_SERVER -eq 1 ] ; then
	building "generating Server $OH_SERVER certificate:"
        for suf in $tcrt $tkey  ; do
           [ $suf ==  $tcrt ] && item=$OH_SETUP_DIR$PKI_CRT"/"$OH_SERVER$suf
           [ $suf == $tkey ] && item=$OH_SETUP_DIR$PKI_KEY"/"$OH_SERVER$suf
           [ -f "$item" ] && cp "$item" "$OH_SETUP_DIR$OH_KEYS" || failed "missing key files $item"
	   [ $? -gt 0 ] && failed "copy key to $OH_SETUP_DIR$OH_KEYS" || passed " ($suf)"
        done
        passed

	checking "generating ovpnhost setup files for $OH_SERVER:$OH_VPN_P :"
	for isuf in "$tconf" "$tup" ; do
	    item=$tserver$isuf
	    sed -e "s%<server_cn>%$OH_SERVER%g ;  s%<server_port>%$OH_VPN_P%g ; s%<path>%..$OH_KEYS%g"  $OH_SETUP_DIR$OH_TEMPLATE$item > $OH_SETUP_DIR$OH_HOST_DIR$item
	    [ $? -gt 0 ]  && failed "sed $item " || passed " - " "updated:${item##*/}"
	done
	chmod u+x "$OH_SETUP_DIR$OH_HOST_DIR$tserver$tup"
	passed
    fi
}


setup_pki () {
    local opt="$1"  item=  itemvars= isuf=
    local item_s="$OH_SETUP_DIR" 
    local item_p=$OH_SETUP_DIR$OH_PKI_DIR
    local item_k=$OH_SETUP_DIR$OH_KEYS

    local item_c=$OH_SETUP_DIR$OH_RSA_DIR

    [ -f $OH_VARS ] && itemvars="--vars=${OH_VARS##*/}"

    checking "checking (rsa-dir)"
    [ ! -d $item_c ] && failed " failed to enter in $item_c"  || passed " - (rsa-script)"
    [ ! -f $item_c$EASYRSA ]  && failed " failed to find  $item_c$EASYRSA" || passed " - (vars-file)"
    [ ! -f $OH_VARS ] && passed ":$OH_VARS not found" || passed ":$itemvars"
    passed
    
    local cdir=$(pwd)
    checking "entering keygen directory $item_c"
    cd $item_c
    passed 

    .$EASYRSA $itemvars | tail -n 5 | head -n 3

    if [ $OH_REINSTALL -eq  1 -o $OH_REKEYGEN -eq 1 ]  ; then
	.$EASYRSA "--batch" $itemvars "init-pki"
	.$EASYRSA "--batch" $itemvars "build-ca" 
	building "building setup certificate name - ca.crt"
	cp  $item_p"/ca.crt"  "$item_k"
	[ $? -gt 0 ] && failed "copy ca to $item_k" || passed
    fi
    
    if [ $OH_REINSTALL -eq 1  -o  $OH_REKEY_SERVER -eq 1 ] ; then
	checking  "verifying server keys for $OH_SERVER" ; passed
	[ $OH_REKEY_SERVER -eq 1 ] && .$EASYRSA "--batch" $itemvars "revoke" $OH_SERVER
	building "removing existing server key file"
	item=$(find $item_c -type f -path '*/'$OH_SERVER'.*')
	for idir in $item ; do
	    rm $idir ; [ $? -gt 0 ]  && failed "rm $idir " || passed " - removed:${idir##*/}"
	done
	passed
	.$EASYRSA "--batch" $itemvars "build-server-full" "$OH_SERVER" "nopass"
    fi
    
    if [ $OH_REINSTALL -eq 1 -o $OH_REKEY_CLIENT -eq 1 ] ; then
	checking "verifying client keys for $OH_CLIENT" ; passed 
	[ $OH_REKEY_CLIENT -eq 1 ] &&  .$EASYRSA "--batch" $itemvars "revoke" $OH_CLIENT
	building "removing existing client key file"
	item=$(find $item_c -type f -path  '*/'$OH_CLIENT'.*')
	for idir in $item ; do
	    rm $idir ; [ $? -gt 0 ]  && failed "rm $idir " || passed " - removed:${idir##*/}"
	done
	passed
	.$EASYRSA "--batch" $itemvars "build-client-full" $OH_CLIENT "nopass"
    fi
    
    if [ $OH_REINSTALL -eq 1 -o $OH_REKEY_DH -eq 1 ] ; then
	.$EASYRSA "--batch" $itemvars "gen-dh" 
	building "generating  dh key - dh.pem"
	cp  $item_p"/dh.pem"  "$item_k"
	[ $? -gt 0 ] && failed "copy ca to $item_k" || passed
    fi
    
    checking "exiting keygen directory - returning to $cdir"
    cd "$cdir"
    passed

}

setup_cn () {
    local opt= val= txt= hdr="general"
 
    while [ -n "$1"  ] ; do
	opt="${1%%=*}" ; val="${1#*=}"
	[ ${#val} -eq 0 -o "$val" == "$opt"  ] && val=""
	shift 1  
	txt="executing CN-cmd $opt for certificate"
	case $opt in
	    -c|-client) OH_REKEY_CLIENT=1  ; [ ${#val} -gt 0 ] &&  OH_CLIENT="$val" ;;
	    -s|-server) OH_REKEY_SERVER=1  ; [ ${#val} -gt 0 ] &&  OH_SERVER="$val" ;;
	    -dh) OH_REKEY_DH=1 ;;
	    -ca) OH_REKEYGEN=1 ;;
	    -q|-end) break ;;
	    -*)txt="skipping unknown CN_cmd option $opt" ; $val=""  ;;
	    *) pmsg "setup-cn option parsing complete with ($opt) CN-cmd" ; break ;;
	esac
	pmsg "$txt $val"
    done
    msg  "Setting"
    [ $OH_REKEYGEN -eq 1 ] && passed " <CA>"
    [ $OH_REKEY_DH -eq 1 ] && passed " <DH>"
    passed " <Server/Client> key CN values to"
    [ ${#OH_CLIENT} -eq 0 ] && OH_CLIENT="vpn1"
    [ ${#OH_SERVER} -eq 0  ] && OH_SERVER="$OH_NAME"  
    passed  " $OH_SERVER/$OH_CLIENT"
    passed

}




setup_rsa () {
    local opt= val=  item="$OH_SETUP_DIR"  sdir=  

    for sdir in  "$OH_HOST_SUBDIRS"  "$OH_RSA_SUBDIRS"  "$OH_JAIL_SUBDIRS" "$PKI_SUBDIRS"
    do
	build_subdirs  "$item"  "$sdir"  
    done 

    building "generating script and conf files :"
    local confs="f=${EASYRSA##*/}  f=${OPENSSL##*/}  f=${VARSRSA##*/}  d=${X509TYPE##*/}"
    for tc in $confs ; do
	opt="${tc%%=*}"
	val="*master*${tc#*=}"
	local path_val=$(find $item"/" -type "$opt" -path  "$val")
	[ ${#path_val} -lt 10 ]  && failed "find $path_val" 
	cp  -rf  $path_val  $item$OH_RSA_DIR"/"
	[ $? -gt 0 ] && failed "copy" ||   passed " -" "${path_val##*/}"
    done
    passed 
}


read_var() {
    local var=$2
    [ -n "$1" -a "$1" != "set_var" ] && failed "vars file corrupted signature 'set_var' expected for $1 $2 $3"
    if [ -n "$3" -a  -n "$2" ] ; then
	local value="$3"
	eval  v=\$$var ; eval $var="\"$value\""
    else
	pmsg "read-vars missing value $3 for var $2 ...passed"
    fi
}
     

set_var() {
    local var=$1
    shift
    local value="$*"
    eval  v=\$$var ; [ "z$v" == "z" ] && eval $var="\"$value\""  ||  eval $var="\"$v\""
    [ ! "$v" == "$value" ]  && pmsg "setting var $var set to $value (setup) - $v (--vars)" || pmsg "var $var  set to $v (setup)"
}

vars_save_cmd () {
    local  item=  sdir=$OH_SETUP_DIR$OH_RSA_DIR 
    local v0="$1"   vv=$OH_VARS    
    
    msg "checking  user --vars file ${v0##*/} "
    [ ! -f "$vv"  -a "$OH_BUILD" -eq 0 ] && failed "var file $vv not found" || passed "$vv "
    [ -f "$v0" -a  "$OH_REINSTALL" -eq 0   ]  && failed "$v0 existing" || passed "$v0 "
    [ ! -f "$sdir$VARSRSA" ] && failed "$VARSRSA not found"  || passed "${VARSRSA##*/} "
    passed
    
    msg  "Easyrsa merging template Var file ${VARSRSA##*/} "
    cat >  "$v0"  "$sdir$VARSRSA" 
    passed "and user vars (--vars)" ;  passed 
    vars_echo_cmd "$v0"
}

vars_delete_cmd () {
    local v0="$1"  
    msg "Deleting   user --vars file ${v0##*/} "
    [ -f "$v0" ] && rm -f "$v0" || passed " (none/skipped)"
    passed 
}

vars_replace_cmd () {
    local v0="$1"   vv=$OH_VARS   sdir=$OH_SETUP_DIR$OH_RSA_DIR
    msg "merging user vars file  ${v0##*/} "
     [ -f "$v0" ] && rm -f "$v0" || passed " (new)"
     [ ! -f "$sdir$VARSRSA" ] && failed "$VARSRSA not found"  
    passed  " template Var file ${VARSRSA##*/} "
    cat >  "$v0"  "$sdir$VARSRSA" 
    passed 
    vars_echo_cmd "$v0"
}

echo_setvar () {
    local v= 
    eval v="\$$1"
    [ -n "$v" ] && echo "set_var $1 \"$v\"" || echo ""
}

vars_echo_cmd () {
    local  v0="$1"  var=
    local hbegin="begin"  hend="end" 
    local htxt="> ##### $OH_SCRIPT_NAME ###### host vpn $OH_NAME generated by $0 <"

local vars=$(cat << END
$(echo_setvar "EASYRSA_DIGEST" )
$(echo_setvar "EASYRSA_SSL_CMD" )
$(echo_setvar "EASYRSA_KEY_SIZE" )
$(echo_setvar "EASYRSA_REQ_COUNTRY" )
$(echo_setvar "EASYRSA_REQ_PROVINCE" )
$(echo_setvar "EASYRSA_REQ_CITY" )
$(echo_setvar "EASYRSA_REQ_ORG" )
$(echo_setvar "EASYRSA_REQ_EMAIL" )
$(echo_setvar "EASYRSA_REQ_OU" )
$(echo_setvar "EASYRSA_REQ_CN" )
$(echo_setvar "EASYRSA_CRL_DAYS" )
END
 ) 
    msg "echoing user-vars settings"
    if [ ${#vars} -gt 25 ] ; then
	if [ ${#v0} -gt 1  -a -f "$v0" ] ; then
	    passed "...updating vars-file ${v0##*/}"  ; passed
	    cp -f "$v0" "$v0.old"
	    awk 'NR==1,/begin|ovpn/ { if (!/begin|ovpn/ ) print $0 }'  "$v0.old" > "$v0"
	    print "echo \"#<ovpn> host $OH_NAME  --vars from ${OH_VARS##*/} ########\""  >> "$v0" 
	    print '#<'$hbegin$htxt'/'$hbegin'>'  >> "$v0"
	    print "$vars" >> "$v0"
	    print '#<'$hend$htxt'/'$hend'>' >> "$v0"  
        else
	    passed  "...vars/value" ; passed
	    for var in "$vars"  ; do 
	        eval "$var"
	    done
	fi
    else
	passed "...skipping (no --vars set)" ; passed  
    fi 
}

vars_load_cmd () {
    local v0="$1"
    msg "loading user-var from file  ${v0##*/}"
    if [ -f "$v0" ] ; then
       passed "...(read/setting-vars)"
       local vars=$(awk '/begin/,/end/ { if (!/begin|end/ && NF>2) print "read_var "$0 }'  "$v0")
       if [ ${#vars} -gt 10 ] ; then
	    passed 
	    eval "$vars" 
      else
         passed  "...no user-vars found) " ; passed 
      fi
    else
	passed "... not found - using easyrsa defaults" ; passed
    fi
}

vars_decode_cmd () {
    local opt= val= hdr="Vars-Cmd cmd/value"
    [ ! -n "$1" ]  && help_init_vars 
    while [ -n "$1"  ] ; do
	opt="${1%%=*}" ; val="${1#*=}"
	[ ${#val} -eq 0 -o "$val" == "$opt"  ] && val="$OH_VARS"  
      pmsg "$hdr executing $opt for vars-file $val"
	case $opt in
	    -s|-save) vars_save_cmd "$val" ;;
	    -d|-delete) vars_delete_cmd "$val" ;;
	    -e|-echo|-status) vars_echo_cmd ;; 
            -l|-load) vars_load_cmd "$val" ;; 
            -r|-replace) vars_replace_cmd "$val" ;;
	    -q|-quit) msg "$hdr complete with ($opt)" ; passed ; shift 1 ; break ;; 
	    -*) msg "$hdr parsing unknown cmd/value" ; failed "$1" ;;
	    *) msg "$hdr complete exiting with ($1)" ; passed ;  break  ;;
	esac
	shift 1
    done
}

setup_git () {
    local opt="$1"  item="$OH_SETUP_DIR"  sdir="$OH_GIT_DIR" zip_dir=

    build_subdirs "$item"  "$sdir"  
    item=$OH_SETUP_DIR$OH_GIT_DIR$OH_GIT_MASTER
    if [ -f $item ] ; then 
	msg "removing previous $OH_GIT_MASTER version"
	rm -f "$item" 
	[ $? -eq 0 ] &&  passed || failed "removing $item"
    fi

    pmsg "Downloading master from Git $OH_GIT_EASYRSA...checking"       
    $OH_WGET_CMD  -v  -P $OH_SETUP_DIR$OH_GIT_DIR  $OH_GIT_EASYRSA
    rc=$?
    building "downloading archive"
    [ $rc -gt 0 ]  && failed "donwload wget"  || passed
    
    building "matching git master file $OH_GIT_SRCSDIR"
    zip_dir=$(unzip -Z1 "$item"  "$OH_GIT_SRCSDIR")
    [ $zip_dir"x" == "x" ] && failed "git version issue" || passed
    
    building "unzipping master configuration files $zip_dir"
    unzip -nqd "$OH_SETUP_DIR" "$item" "$zip_dir*"
    [ $? -gt 0 ] && failed "unzip" || passed

}

setup_varsfile () {
     local txtv= txtd=  item=
    # Intelligent env-var detection and auto-loading:
    
    pmsg "Working Host-Ovpn-Full-EasyRsa-SETUP(Script)name : $OH_SETUP_CMD" 
    pmsg "Working script path : $OH_SETUP_PATH"
    pmsg "Working (root) path directory : $OH_ROOT_DIR" 
    
    [ ${#EASYRSA_SSL_CMD} -gt 1 ]  && item="$EASYRSA_SSL_CMD" || item=$(type openssl) 
    [ -f $item ] && version=$($item version 2>/dev/null | head -n 1) || failed "module $item not found"
    pmsg "Working (SSL-lib) $version on host $(uname -nm)" 

    msg "Setting (vpn-name) - "
    if [ ${#OH_NAME} -gt 1 ] ; then
	txtv="using --vars"
       if [ ${#OH_SETUP_DIR} -gt 1 ] ; then
       	  #OH_SETUP_DIR=$(absPath "$OH_SETUP_DIR'/'$OH_NAME")
	  txtd="using --vars"
       else
	  #OH_SETUP_DIR=$OH_ROOT_DIR"/"$OH_NAME
          #txtd="defaulted to (root)/(vpn-name)"
          textd="using --vars"
       fi 
    else
        if [ ${#OH_SETUP_DIR} -gt 1 ] ; then
	  txtv="defaulted to (setup-dir)"
	  txtd="using --vars"
          #OH_SETUP_DIR=$(absPath "$OH_SETUP_DIR")
	  OH_NAME=${OH_SETUP_DIR##*/}
	else
	  failed "and (setup-dir) not specified"  
	fi
    fi
    passed "$txtv=$OH_NAME" ; passed
  
    msg "Setting (setup-dir) - "
    if [ ${#OH_SETUP_DIR} -gt 1 ] ; then
	txtv="using --vars"
       if [ ${#OH_NAME} -gt 1 ] ; then
       	  #OH_SETUP_DIR=$(absPath "$OH_SETUP_DIR'/'$OH_NAME")
	  txtd="using --vars"
       else
	  #OH_SETUP_DIR=$OH_ROOT_DIR"/"$OH_NAME
          #txtd="defaulted to (root)/(vpn-name)"
          textd="using --vars"
       fi 
    else
        if [ ${#OH_NAME} -gt 1 ] ; then
	  txtv="defaulted to (vpn-name)"
	  txtd="using --vars"
          #OH_SETUP_DIR=$(absPath "$OH_SETUP_DIR")
	  OH_SETUP_DIR="$OH_NAME"
	else
	  failed "and (vpn-name) not specified"  
	fi
    fi
    passed "$txtv=$OH_SETUP_DIR" ; passed

    msg "Setting (vars-file) - " 
    if [ ${#OH_VARS} -le 1 ] ; then
	OH_VARS="vars."$OH_NAME
	txtv="defaulted to (vpn-name)"
    else
	txtv="using --vars"
    fi
    passed "$txtv=$OH_VARS" ; passed
 
    txtv="finding (vars-file) - path:"
    var="$OH_SETUP_DIR$OH_RSA_DIR/$OH_VARS"
    for vard in "(setup)="$OH_SETUP_DIR$OH_RSA_DIR  "(root)="$OH_ROOT_DIR "(.)="$OH_SETUP_PATH ; do
	vard_type=${vard%%=*} ; vard_name=${vard#*=} 
	msg "$txtv$vard_type=$vard_name"
	if [ -f "$vard_name/$OH_VARS" ]  ; then 
	    OH_VARS_SETUP="$vard_name/$OH_VARS" 
	    passed "...found"
	else
	    passed "...none"
	fi
	passed
    done
    [ ! -f $OH_VARS_SETUP ] && OH_VARS_SETUP="$var" 
    OH_VARS="$var"
}

setup_dirs () {
    local opt="$1"  cmd=0

   OH_BUILD=0 ; OH_REINSTALL=0  ; OH_WARNDIR=0 ; OH_EXISTDIR=0 ; OH_RESETDIR=0
    while [ -n "$1"  ] ; do
	opt="$1" ; shift 1  
	case $opt in
	    -b|-build) OH_BUILD=1   ;;
	    -r|-reinstall) OH_REINSTALL=1  ;;
	    -w|-warn) OH_WARNDIR=1 ;;
           -e|-exist) OH_EXISTDIR=1 ;;
           -z|-reset) OH_RESETDIR=1 ;;
           -xeq) cmd=1 ;;
	    -*)txt="Setting dirs - skipping unknown option $opt"   ;;
	    *) pmsg "Setting dirs option parsing complete with ($opt) " ; break ;;
	esac
    done
    if [ $cmd -eq 1 ] ; then 
	msg  "Setting dirs option to"
        [ $OH_BUILD -eq 1 ] && passed " (make)"
        [ $OH_REINSTALL -eq 1 ] && passed " (reuse)"
        [ $OH_WARNDIR -eq 1 ] && passed " (check)"
        [ $OH_RESETDIR -eq 1 ] && passed " (reset)"
        [ $OH_EXISTDIR -eq 1 ] && passed " (verify)"
        passed
        
        local  item=$OH_SETUP_DIR  sdir= tdir=
        pmsg "Checking setup-dir-path status for $OH_NAME"
        if [ $OH_WARNDIR -eq 1 ] ; then
            for tdir in "$OH_SETUP_PATH" "$OH_ROOT_DIR" 
            do
                sdir="$tdir"/"$item"
                build_subdirs  "" "$sdir" 
                [ -d "$sdir" ] && OH_ROOT_DIR="$tdir"
            done
        fi
       
        msg "Entering in Setup-path - "
        item="$OH_ROOT_DIR"/"$OH_SETUP_DIR"
        if [ ! -d "$item" -a $OH_BUILD -eq 1 ] ; then
            mkdir -p "$item"
            passed "(mkdir)"
        else
            passed "(reuse)"
        fi
        cd "$item"
        passed " $(pwd -P)" ; passed
        OH_SETUP_DIR="$item" 
        pmsg "Checking sub directories status for (Setup-dir) $OH_SETUP_DIR" 
        for sdir in "$OH_SETUP_SUBDIRS"  "$OH_HOST_SUBDIRS"  "$OH_RSA_SUBDIRS"  "$OH_JAIL_SUBDIRS" "$PKI_SUBDIRS"
        do
	      build_subdirs  "$item"  "$sdir"  
        done 
    fi
}

setup_exec () {
    # determine how we were called, then hand off to the function responsible 
    local cmd=  txt=
    
    while [ -n "$1" ] ; do

       cmd="$1"
       shift 1  # scrape off command
	setup_dirs  -warn
	case "$cmd" in
	    -*)		txt="$cmd"	;;
	    dirs)	setup_dirs  -warn -xeq   ;;
            dirs-cmd)	setup_dirs "$@" ;;
	    git)	setup_git  ;;
            vars)	vars_decode_cmd "$@" ;;
	    rsa)	setup_rsa  ;;
            cn-names)	setup_cn "$@" ;;

	    pki)  
		setup_cn "$@" ; setup_pki  
		;;
	    pkib)   
		setup_dirs  -reset  ; setup_pki  
		;;
	    ovpn-templates) 
		setup_dirs '-z' ; setup_ovpn  
		;;
	    ovpn)
		setup_dirs -reinstall ; setup_cn "$@"  ; setup_ovpn  
		;;
	    rekey)  
		setup_dirs  -exist
		#pmsg "Server/Client key regen CN default --vars $OH_SERVER/$OH_CLIENT"
		setup_cn "$@"
		vars_load_cmd  "$OH_VARS"
		setup_pki  
		setup_ovpn 
		;;
	    full)  
                setup_dirs  -build -reset -xeq
		setup_git  
		setup_rsa 
                vars_decode_cmd '-load='$OH_VARS_SETUP '-echo' '-replace='$OH_VARS '-q'
		setup_cn -ca -dh -s -c "$@"
		setup_pki 
		setup_ovpn 
		;;
	    init)
                setup_dirs -build -reset -xeq
		setup_git  
		setup_rsa 
		;;
	    var)
		setup_dirs  -build ; 
		vars_decode_cmd '-load='$OH_VARS_SETUP '-echo' '-replace='$OH_VARS '-q'
		;;
            boot) 
                setup_dirs -warn -xeq ;
		build_bootstrap " --vpn=$OH_NAME $OH_INSTALL_CMD $@"
		;; 
            install) 
                setup_dirs -warn -xeq ;
                ETC_SETUP_DIR="$OH_ROOT_DIR"/"$OH_SETUP_DIR"
		install_main "--vpn=$OH_NAME $OH_INSTALL_CMD  $@"
		;;
	    cli) [ ! -n "$1" ] && help_build_cli  
		;;
            usage) cmd_help "$@" ; break
		;;
	    *) pmsg   "Build_cli - Ignoring unknown command option: $cmd" 
		;;
	esac
    done
}

setup_main () {

    while [ $# -gt 0 ] ; do
	opt="${1%%=*}"
	val="${1#*=}"
	empty_ok= 						# Empty values are not allowed unless excepted

	case $opt in
	    --x)  set -x ; print "debug mode set" ; empty_ok=1 ;;
	    --vpn) OH_NAME=$val ;;
	    --setup-dir) OH_SETUP_DIR=$val ;;       
	    --rsa-git) OH_RSA_GIT="$val"  ;;
	    --vpn-dns) OH_VPN_D="${val%:*}" ;  OH_VPN_P="${val##*:}" ;;
	    --vars) OH_VARS="$val"  ;;
	    --cn-client) OH_CLIENT="$val" ;;
	    --cn-server) OH_SERVER="$val" ;;
	    --wget-cmd) OH_WGET_CMD="$val" ;;

	    --install-cmd) OH_INSTALL_CMD="$val" ;;
	    --ssl-cmd) EASYRSA_SSL_CMD="$val" ;;

	    --digest) EASYRSA_DIGEST="$val" ;;
	    --days) EASYRSA_CRL_DAYS="$val" ;;  # =# sets the signing validity number of days  
	    --keysize) EASYRSA_KEY_SIZE="$val" ;;  # =#     : size in bits of keypair to generate
	    --req-cn) EASYRSA_REQ_CN="$val" ;;  # =NAME   : default CN to use
	    --req-cc) EASYRSA_REQ_COUNTRY="$val" ;;  # =CC        : country code (2-letters)
	    --req-st) EASYRSA_REQ_PROVINCE="$val" ;;  # =NAME     : State/Province
	    --req-city) EASYRSA_REQ_CITY="$val" ;;  # =NAME   : City/Locality
	    --req-org) EASYRSA_REQ_ORG="$val" ;;  # =NAME    : Organization
	    --req-email) EASYRSA_REQ_EMAIL="$val" ;;  # =NAME  : Email addresses
	    --req-ou) EASYRSA_REQ_OU="$val" ;;  #      : Organizational Unit
	    -*) msg "unknown global option/value" ; failed "$1" ;; 
	    *) break ;;
	esac

	# fatal error when no value was provided
	if [ ! $empty_ok ] && { [ "$val" = "$1" ] || [ -z "$val" ]; }; then
	    failed   "Missing value to option: $opt"
	fi

	shift
    done

    # determine how we were called, then hand off to the function responsible
    local cmd="$1" b_cmd=""
    [ -n "$1" ] && shift 1 || cmd="help" # scrape off command

    case "$cmd" in
	init-pki|clean-all) b_cmd="init"    ;;
	init-vars) b_cmd="var"    ;;
	build-ca) b_cmd="rekey -ca"   ;;
	gen-dh) b_cmd="rekey -dh"    ;;
	build-client-full) b_cmd="rekey -client"    ;;
	build-server-full) b_cmd="rekey -server"     ;;
	build-full) b_cmd="full"     ;;
	build) b_cmd="cli"    ;;
	help|-h|--help|--usage) cmd_help "$@" ; exit 0  ;;
	gen-bootstrap) b_cmd="boot"  ;;
	install) b_cmd="install"  ;;
	*) failed  "Unknown command build $cmd. Run without commands for usage help."    ;;
    esac
    setup_varsfile
    setup_exec $b_cmd "$@"
    exit 0
}

[ "$OH_SETUP_CMD" != "${OH_BOOT_CMD##*/}" ]  && setup_main "$@"


ZEND
