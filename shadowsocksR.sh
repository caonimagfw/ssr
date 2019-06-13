#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

#===========================================================#
# One Click Install ShadowsocksR Server for CentOS & Debian #
# Github: https://github.com/uxh/shadowsocks_bash           #
# Thanks: https://github.com/teddysun/shadowsocks_install   #
#===========================================================#

#Libsodium
libsodium_ver="1.0.16"
libsodium_url="https://github.com/jedisct1/libsodium/releases/download/1.0.16/libsodium-1.0.16.tar.gz"

#Current folder
cur_dir=`pwd`

#Stream ciphers
ciphers=(
aes-256-cfb
aes-256-ctr
chacha20-ietf
chacha20
rc4-md5
none
)

#Protocol
protocols=(
origin
auth_sha1_v4
auth_aes128_md5
auth_aes128_sha1
auth_chain_a
auth_chain_b
auth_chain_c
auth_chain_d
auth_chain_e
)

#Obfs
obfs=(
plain
http_simple
http_post
tls1.2_ticket_auth
tls1.2_ticket_fastauth
)

#Color
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

#Make sure root
[[ $EUID -ne 0 ]] && echo -e "[${red}Error${plain}] This script must be run as root!" && exit 1

#Start info
start_info(){
    clear
    echo "#===========================================================#"
    echo "# One Click Install ShadowsocksR Server for CentOS & Debian #"
    echo "# Github: https://github.com/uxh/shadowsocks_bash           #"
    echo "# Thanks: https://github.com/teddysun/shadowsocks_install   #"
    echo "#===========================================================#"
}

#Disable selinux
disable_selinux(){
    if [ -s /etc/selinux/config ] && grep 'SELINUX=enforcing' /etc/selinux/config; then
        sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
        setenforce 0
    fi
}

#Check system type
check_sys(){
    local checkType=$1
    local value=$2

    local release=''
    local systemPackage=''

    if [[ -f /etc/redhat-release ]]; then
        release="centos"
        systemPackage="yum"
    elif cat /etc/issue | grep -Eqi "debian"; then
        release="debian"
        systemPackage="apt"
    elif cat /etc/issue | grep -Eqi "centos|red hat|redhat"; then
        release="centos"
        systemPackage="yum"
    elif cat /proc/version | grep -Eqi "debian"; then
        release="debian"
        systemPackage="apt"
    elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
        release="centos"
        systemPackage="yum"
    fi

    if [[ ${checkType} == "sysRelease" ]]; then
        if [ "$value" == "$release" ]; then
            return 0
        else
            return 1
        fi
    elif [[ ${checkType} == "packageManager" ]]; then
        if [ "$value" == "$systemPackage" ]; then
            return 0
        else
            return 1
        fi
    fi
}

#Get version
getversion(){
    if [[ -s /etc/redhat-release ]]; then
        grep -oE  "[0-9.]+" /etc/redhat-release
    else
        grep -oE  "[0-9.]+" /etc/issue
    fi
}

#CentOS version
centosversion(){
    if check_sys sysRelease centos; then
        local code=$1
        local version="$(getversion)"
        local main_ver=${version%%.*}
        if [ "$main_ver" == "$code" ]; then
            return 0
        else
            return 1
        fi
    else
        return 1
    fi
}

#Get public ip
get_ip(){
    local IP=$( ip addr | egrep -o '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | egrep -v "^192\.168|^172\.1[6-9]\.|^172\.2[0-9]\.|^172\.3[0-2]\.|^10\.|^127\.|^255\.|^0\." | head -n 1 )
    [ -z ${IP} ] && IP=$( wget -qO- -t1 -T2 ipv4.icanhazip.com )
    [ -z ${IP} ] && IP=$( wget -qO- -t1 -T2 ipinfo.io/ip )
    [ ! -z ${IP} ] && echo ${IP} || echo
}

#Get char
get_char(){
    SAVEDSTTY=`stty -g`
    stty -echo
    stty cbreak
    dd if=/dev/tty bs=1 count=1 2> /dev/null
    stty -raw
    stty echo
    stty $SAVEDSTTY
}

#Pre configure
pre_configure(){
    if check_sys packageManager yum || check_sys packageManager apt; then
        if centosversion 5; then
            echo -e "${red}This script do not support CentOS5!${plain}"
            exit 1
        fi
    else
        echo -e "${red}This script only support CentOS6/7 and Debian7/8!${plain}"
        exit 1
    fi

    echo "Please Enter ShadowsocksR's Password"
    read -p "(Default: Number123890):" shadowsockspwd
    [ -z "${shadowsockspwd}" ] && shadowsockspwd="Number123890"
    echo "-------------------------"
    echo "Password = ${shadowsockspwd}"
    echo "-------------------------"

    while true
    do
    dport=$(shuf -i 3000-8888 -n 1)
    echo "Please Enter ShadowsocksR's Port (1~65535)"
    read -p "(Default: ${dport}):" shadowsocksport
    [ -z "${shadowsocksport}" ] && shadowsocksport=${dport}
    expr ${shadowsocksport} + 1 &>/dev/null
    if [ $? -eq 0 ]; then
        if [ ${shadowsocksport} -ge 1 ] && [ ${shadowsocksport} -le 65535 ] && [ ${shadowsocksport:0:1} != 0 ]; then
            echo "-------------------------"
            echo "Port = ${shadowsocksport}"
            echo "-------------------------"
            break
        fi
    fi
    echo -e "${red}Please enter a number between 1 and 65535!${plain}"
    done

    while true
    do
    echo -e "Please Select ShadowsocksR's Stream Cipher"
    for ((i=1;i<=${#ciphers[@]};i++ )); do
        hint="${ciphers[$i-1]}"
        echo -e "${i}) ${hint}"
    done
    read -p "(Default: ${ciphers[0]}):" pick
    [ -z "$pick" ] && pick=1
    expr ${pick} + 1 &>/dev/null
    if [ $? -ne 0 ]; then
        echo -e "${red}Please enter a number!${plain}"
        continue
    fi
    if [[ "$pick" -lt 1 || "$pick" -gt ${#ciphers[@]} ]]; then
        echo -e "${red}Please enter a number between 1 and ${#ciphers[@]}!${plain}"
        continue
    fi
    shadowsockscipher=${ciphers[$pick-1]}
    echo "-------------------------"
    echo "Stream Cipher = ${shadowsockscipher}"
    echo "-------------------------"
    break
    done

    while true
    do
    echo -e "Please Select ShadowsocksR's Protocol"
    for ((i=1;i<=${#protocols[@]};i++ )); do
        hint="${protocols[$i-1]}"
        echo -e "${i}) ${hint}"
    done
    read -p "(Default: ${protocols[0]}):" protocol
    [ -z "$protocol" ] && protocol=1
    expr ${protocol} + 1 &>/dev/null
    if [ $? -ne 0 ]; then
        echo -e "${red}Please enter a number!${plain}"
        continue
    fi
    if [[ "$protocol" -lt 1 || "$protocol" -gt ${#protocols[@]} ]]; then
        echo -e "${red}Please enter a number between 1 and ${#protocols[@]}!${plain}"
        continue
    fi
    shadowsockprotocol=${protocols[$protocol-1]}
    echo "-------------------------"
    echo "Protocol = ${shadowsockprotocol}"
    echo "-------------------------"
    break
    done

    while true
    do
    echo -e "Please Select ShadowsocksR's Obfs"
    for ((i=1;i<=${#obfs[@]};i++ )); do
        hint="${obfs[$i-1]}"
        echo -e "${i}) ${hint}"
    done
    read -p "(Default: ${obfs[0]}):" r_obfs
    [ -z "$r_obfs" ] && r_obfs=1
    expr ${r_obfs} + 1 &>/dev/null
    if [ $? -ne 0 ]; then
        echo -e "${red}Please enter a number!${plain}"
        continue
    fi
    if [[ "$r_obfs" -lt 1 || "$r_obfs" -gt ${#obfs[@]} ]]; then
        echo -e "${red}Please enter a number between 1 and ${#obfs[@]}!${plain}"
        continue
    fi
    shadowsockobfs=${obfs[$r_obfs-1]}
    echo "-------------------------"
    echo "obfs = ${shadowsockobfs}"
    echo "-------------------------"
    break
    done

    echo
    echo "Press Enter to start...or Press Ctrl+C to cancel"
    char=`get_char`

    if check_sys packageManager yum; then
        yum install python python-devel python-setuptools openssl openssl-devel curl wget unzip gcc automake autoconf make libtool -y
    elif check_sys packageManager apt; then
        apt-get update
        apt-get install python python-dev python-setuptools openssl libssl-dev curl wget unzip gcc automake autoconf make libtool -y
    fi
}

#Download files
download_files(){
    cd ${cur_dir}

    if ! wget --no-check-certificate -O libsodium-${libsodium_ver}.tar.gz ${libsodium_url}; then
        echo -e "[${red}Failed to download libsodium-${libsodium_ver}.tar.gz!${plain}"
        exit 1
    fi

    if ! wget --no-check-certificate -O shadowsocksr-3.2.1.tar.gz https://github.com/shadowsocksrr/shadowsocksr/archive/3.2.1.tar.gz; then
        echo -e "[${red}Failed to download ShadowsocksR file!${plain}"
        exit 1
    fi

    if check_sys packageManager yum; then
        if ! wget --no-check-certificate https://raw.githubusercontent.com/uxh/shadowsocks_bash/master/shadowsocksR -O /etc/init.d/shadowsocks; then
            echo -e "[${red}Failed to download ShadowsocksR chkconfig file!${plain}"
            exit 1
        fi
    elif check_sys packageManager apt; then
        if ! wget --no-check-certificate https://raw.githubusercontent.com/uxh/shadowsocks_bash/master/shadowsocksR-debian -O /etc/init.d/shadowsocks; then
            echo -e "[${red}Failed to download ShadowsocksR chkconfig file!${plain}"
            exit 1
        fi
    fi
}

#Set firewall
set_firewall(){
    echo -e "${green}Start set firewall...${plain}"
    if centosversion 6; then
        /etc/init.d/iptables status > /dev/null 2>&1
        if [ $? -eq 0 ]; then
            iptables -L -n | grep -i ${shadowsocksport} > /dev/null 2>&1
            if [ $? -ne 0 ]; then
                iptables -I INPUT -m state --state NEW -m tcp -p tcp --dport ${shadowsocksport} -j ACCEPT
                iptables -I INPUT -m state --state NEW -m udp -p udp --dport ${shadowsocksport} -j ACCEPT
                /etc/init.d/iptables save
                /etc/init.d/iptables restart
            else
                echo -e "${green}Port ${shadowsocksport} has been opened!${plain}"
            fi
        else
            echo -e "${yellow}Firewall looks like not running or not installed, please enable port ${shadowsocksport} manually if necessary!${plain}"
        fi
    elif centosversion 7; then
        systemctl status firewalld > /dev/null 2>&1
        if [ $? -eq 0 ]; then
            firewall-cmd --permanent --zone=public --add-port=${shadowsocksport}/tcp
            firewall-cmd --permanent --zone=public --add-port=${shadowsocksport}/udp
            firewall-cmd --reload
        else
            echo -e "${yellow}Firewall looks like not running or not installed, please enable port ${shadowsocksport} manually if necessary!${plain}"
        fi
    fi
    echo -e "${green}Firewall set completed!${plain}"
}

#Config shadowsocks
config_shadowsocks(){
    cat > /etc/shadowsocks.json << EOF
{
    "server":"0.0.0.0",
    "server_ipv6":"[::]",
    "server_port":${shadowsocksport},
    "local_address":"127.0.0.1",
    "local_port":1080,
    "password":"${shadowsockspwd}",
    "timeout":120,
    "method":"${shadowsockscipher}",
    "protocol":"${shadowsockprotocol}",
    "protocol_param":"",
    "obfs":"${shadowsockobfs}",
    "obfs_param":"",
    "redirect":"",
    "dns_ipv6":false,
    "fast_open":false,
    "workers":1
}
EOF
}

#Install
install(){
    if [ ! -f /usr/lib/libsodium.a ]; then
        cd ${cur_dir}
        tar zxf libsodium-${libsodium_ver}.tar.gz
        cd libsodium-${libsodium_ver}
        ./configure --prefix=/usr && make && make install
        if [ $? -ne 0 ]; then
            echo -e "${red}Failed to install libsodium!${plain}"
            install_cleanup
            exit 1
        fi
    fi

    ldconfig

    cd ${cur_dir}
    tar zxf shadowsocksr-3.2.1.tar.gz
    mv shadowsocksr-3.2.1/shadowsocks /usr/local/
    if [ -f /usr/local/shadowsocks/server.py ]; then
        chmod +x /etc/init.d/shadowsocks
        if check_sys packageManager yum; then
            chkconfig --add shadowsocks
            chkconfig shadowsocks on
        elif check_sys packageManager apt; then
            update-rc.d -f shadowsocks defaults
        fi
        /etc/init.d/shadowsocks start
        install_success
        qr_link
    else
        echo "${red}Failed to install ShadowsocksR!${plain}"
        install_cleanup
        exit 1
    fi
}

#Modify
modify(){
    /etc/init.d/shadowsocks restart
    install_success
    qr_link
}

#Install success
install_success(){
    clear
    echo -e "${green}Congratulations, ShadowsocksR server install completed!${plain}"
    echo -e "------------------------------------------------------------"
    echo -e "Your Server IP        : \033[41;37m $(get_ip) \033[0m"
    echo -e "Your Server Port      : \033[41;37m ${shadowsocksport} \033[0m"
    echo -e "Your Password         : \033[41;37m ${shadowsockspwd} \033[0m"
    echo -e "Your Protocol         : \033[41;37m ${shadowsockprotocol} \033[0m"
    echo -e "Your Obfs             : \033[41;37m ${shadowsockobfs} \033[0m"
    echo -e "Your Encryption Method: \033[41;37m ${shadowsockscipher} \033[0m"
    echo -e "------------------------------------------------"
}

#Qr link
qr_link() {
    local tmp1=$(echo -n "${shadowsockspwd}" | base64 -w0 | sed 's/=//g;s/\//_/g;s/+/-/g')
    local tmp2=$(echo -n "$(get_ip):${shadowsocksport}:${shadowsockprotocol}:${shadowsockscipher}:${shadowsockobfs}:${tmp1}/?obfsparam=" | base64 -w0)
    local tmp3="ssr://${tmp2}"
    echo -e "${tmp3}"
    echo
}

#Install cleanup
install_cleanup(){
    cd ${cur_dir}
    rm -rf shadowsocksr-3.2.1.tar.gz shadowsocksr-3.2.1 libsodium-${libsodium_ver}.tar.gz libsodium-${libsodium_ver}
}

#Install shadowsocksr
install_shadowsocksr(){
    start_info
    disable_selinux
    pre_configure
    download_files
    config_shadowsocks
    if check_sys packageManager yum; then
        set_firewall
    fi
    install
    install_cleanup
}

#Modify shadowsocksr
modify_shadowsocksr(){
    start_info
    pre_configure
    config_shadowsocks
    if check_sys packageManager yum; then
        set_firewall
    fi
    modify
    install_cleanup
}

#Uninstall shadowsocksr
uninstall_shadowsocksr(){
    echo "Continue to uninstall ShadowsocksR? (y/n)"
    read -p "(Default: n):" answer
    [ -z ${answer} ] && answer="n"
    if [ "${answer}" == "y" ] || [ "${answer}" == "Y" ]; then
        /etc/init.d/shadowsocks status > /dev/null 2>&1
        if [ $? -eq 0 ]; then
            /etc/init.d/shadowsocks stop
        fi
        if check_sys packageManager yum; then
            chkconfig --del shadowsocks
        elif check_sys packageManager apt; then
            update-rc.d -f shadowsocks remove
        fi
        rm -f /etc/shadowsocks.json
        rm -f /etc/init.d/shadowsocks
        rm -f /var/log/shadowsocks.log
        rm -rf /usr/local/shadowsocks
        echo -e "${green}ShadowsocksR has been removed!${plain}"
    else
        echo
    fi
}

action=$1
[ -z $1 ] && action=install
case "$action" in
    install|modify|uninstall)
        ${action}_shadowsocksr
        ;;
    *)
        echo "Arguments error! [${action}]"
        echo "Usage: `basename $0` [install|uninstall]"
        ;;
esac
