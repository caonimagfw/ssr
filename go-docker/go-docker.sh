#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

#=================================================
#	.@@.
#=================================================

Green_font_prefix="\033[32m"
Red_font_prefix="\033[31m"
Green_background_prefix="\033[42;37m"
Red_background_prefix="\033[41;37m"
Font_color_suffix="\033[0m"


install_docker(){
	#update fire wall
	echo -e "update firewall.@@."
	systemctl stop firewalld && yum -y upgrade firewalld
	systemctl enable firewalld && systemctl restart firewalld
	firewall-cmd --permanent --zone=trusted --add-port=8099/tcp
	firewall-cmd --permanent --zone=trusted --add-port=80/tcp --add-port=443/tcp --add-port=8888/tcp
	firewall-cmd --permanent --zone=public  --add-forward-port=port=443:proto=tcp:toport=8020
	firewall-cmd --permanent --zone=public  --add-masquerade
	firewall-cmd --permanent --zone=trusted --add-masquerade
	firewall-cmd --reload

	echo -e "install tools.@@."
	yum -y install wget net-tools bridge-utils && yum -y install epel-release && yum -y install unar
		wget --no-check-certificate -O caddy_install.sh https://raw.githubusercontent.com/caonimagfw/Caddy/master/caddy_install.sh && bash caddy_install.sh
	cat > /usr/local/caddy/Caddyfile <<-EOF
:80 {
	redir https://{host}
}

:8099 {
	root /usr/local/caddy/www
	gzip
}
EOF
	cat /usr/local/caddy/Caddyfile
	service caddy restart

	echo -e "install docker soft.@@."
	yum install -y yum-utils device-mapper-persistent-data lvm2
	yum-config-manager \
	    --add-repo \
	    https://download.docker.com/linux/centos/docker-ce.repo
	yum makecache fast
	yum list docker-ce --showduplicates | sort -r
	yum -y install docker-ce-19.03.11 docker-ce-cli-19.03.11 containerd.io

	systemctl restart docker  
		
	iptables -t nat -F 
	ifconfig docker0 down 
	brctl delbr docker0 
	systemctl restart firewalld && systemctl restart docker
	firewall-cmd --permanent --zone=trusted --add-interface=docker0 && firewall-cmd --reload
	systemctl enable docker
	echo -e "install docker done.@@."

}

install_data(){
    yum -y install wget epel-release unar

	# get key
    if [ ! -d "/root/ssl" ]; then
        #not exists 
        mkdir /root/ssl     
    fi 

	cd /root/ssl 
	wget --no-check-certificate  https://github.com/caonimagfw/LuyouFrame/raw/master/18.06.8/Mine/gfw.com/gfw.com.key.rar
	unar -D -o gfw.com -p ${datapwd} gfw.com.key.rar && rm -rf *.rar
	
	# get docker
    if [ ! -d "/root/docker" ]; then
        #not exists 
        mkdir /root/docker   
    fi 	
	cd /root/docker 
	wget --no-check-certificate  https://github.com/caonimagfw/LuyouFrame/raw/master/18.06.8/Mine/gfw.com/gfw.com.docker.rar
	unar -D -p ${datapwd} gfw.com.docker.rar && rm -rf *.rar

	docker import gfw.com.tar trojango
	docker run -itd -v /root/ssl:/opt/ssl -p 8888:80 -p 8020:443 --restart always --name openwrt trojango /sbin/init
}
#args
datapwd=$1

if test -z "$datapwd" ;then
	datapwd="1234"
fi

into_docker(){
	docker exec -it openwrt /bin/sh
}




install_bbr(){
	echo -e "update kernel.@@."
	# rpm -Va --nofiles --nodigest
	wget -N -O kernel-ml-c5.6.15.rpm https://github.com/caonimagfw/onefast/raw/master/bbr/centos/7/x64/kernel-ml-5.6.15-1.el7.elrepo.x86_64.rpm
	wget -N -O kernel-ml-c5.6.15-headers.rpm https://github.com/caonimagfw/onefast/raw/master/bbr/centos/7/x64/kernel-ml-headers-5.6.15-1.el7.elrepo.x86_64.rpm

	yum remove kernel-headers
	yum install -y kernel-ml-c5.6.15.rpm kernel-ml-c5.6.15-headers.rpm
	
	#Error: kernel-ml-headers conflicts 
	#载入公钥
	
	#rpm --import https://www.elrepo.org/RPM-GPG-KEY-elrepo.org
	#rpm -–import https://www.elrepo.org/RPM-GPG-KEY-elrepo.org
	#升级安装ELRepo
	#rpm -Uvh https://www.elrepo.org/elrepo-release-7.0-3.el7.elrepo.noarch.rpm 
	#rpm -Uvh https://www.elrepo.org/elrepo-release-7.0-4.el7.elrepo.noarch.rpm
	# rpm -Uvh http://www.elrepo.org/elrepo-release-7.0-2.el7.elrepo.noarch.rpm
	#yum install https://www.elrepo.org/elrepo-release-7.0-3.el7.elrepo.noarch.rpm 
	#载入elrepo-kernel元数据
	#yum --disablerepo="*" --enablerepo="elrepo-kernel"  list available
	#yum --disablerepo=\* --enablerepo=elrepo-kernel list available
	#查看可用的rpm包
	# yum –enablerepo=elrepo-kernel -y install kernel-ml kernel-ml-devel -

	#yum –-enablerepo=elrepo-kernel install kernel-ml -y
	#yum --enablerepo=elrepo-kernel install kernel-ml -y
	#kernel-ml-
	#yum --disablerepo='*' --enablerepo=elrepo-kernel install kernel-ml
	#安装最新版本的kernel
	#yum --disablerepo=\* --enablerepo=elrepo-kernel install kernel-ml.x86_64  -y

	cat > /etc/sysctl.conf <<-EOF
fs.file-max = 1024000
fs.inotify.max_user_instances = 8192
net.core.netdev_max_backlog = 262144
net.core.rmem_default = 8388608
net.core.rmem_max = 67108864
net.core.somaxconn = 65535
net.core.wmem_default = 8388608
net.core.wmem_max = 67108864
net.ipv4.ip_local_port_range = 10000 65000
net.ipv4.route.gc_timeout = 100
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_fin_timeout = 30
net.ipv4.tcp_keepalive_time = 1200
net.ipv4.tcp_max_orphans = 3276800
net.ipv4.tcp_max_syn_backlog = 65536
net.ipv4.tcp_max_tw_buckets = 60000
net.ipv4.tcp_mem = 94500000 915000000 927000000
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_rmem = 4096 87380 67108864
net.ipv4.tcp_sack = 1
net.ipv4.tcp_syn_retries = 2
net.ipv4.tcp_synack_retries = 2
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_timestamps = 1
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_wmem = 4096 65536 67108864
net.netfilter.nf_conntrack_max = 6553500
net.netfilter.nf_conntrack_tcp_timeout_close_wait = 60
net.netfilter.nf_conntrack_tcp_timeout_established = 3600
net.netfilter.nf_conntrack_tcp_timeout_fin_wait = 120
net.netfilter.nf_conntrack_tcp_timeout_time_wait = 120
net.nf_conntrack_max = 6553500
net.ipv4.ip_forward = 1
net.ipv4.tcp_congestion_control = bbr
net.core.default_qdisc=fq
EOF
	cat /etc/sysctl.conf
	sysctl -p


	modprobe tcp_bbr
	sysctl -w net.core.default_qdisc=fq
	sysctl -w net.ipv4.tcp_congestion_control=bbr
	echo "tcp_bbr" >> /etc/modules-load.d/modules.conf

	cat > /etc/security/limits.conf <<-EOF
*               soft    nofile          1000000
*               hard    nofile          1000000
EOF

	echo "ulimit -SHn 1000000">>/etc/profile

	sudo egrep ^menuentry /etc/grub2.cfg | cut -f 2 -d \'
	sudo grub2-set-default 0

	echo -e "update done please reboot.@@."

}


# start menu
mainControl(){
	clear
	echo
	echo -e " A Script ${Red_font_prefix}.@@.${Font_color_suffix}"
	echo
	echo -e "————————————Install————————————"
	echo -e "${Green_font_prefix}1.${Font_color_suffix} Update Kernel"
	echo -e "${Green_font_prefix}2.${Font_color_suffix} Install Docker Soft" 
	echo -e "${Green_font_prefix}3.${Font_color_suffix} Install Docker Data"
	echo -e "————————————Operate————————————"
	echo -e "${Green_font_prefix}4.${Font_color_suffix} Go Inside of Docker "
	echo -e "————————————Exit————————————"
	echo -e "${Green_font_prefix}0.${Font_color_suffix} Exit"
	echo -e "————————————————————————————————"
	echo
	
echo
read -p " 请输入数字 [0-4]:" num
case "$num" in
	1)
	install_bbr
	;;
	2)
	install_docker
	;;
	3)
	install_data
	;;
	4)
	into_docker
	;;	
	0)
	exit 1
	;;	
	*)
	clear
	echo -e "${Error}:请输入正确数字 [0-12]"
	sleep 3s
	mainControl
	;;
esac
}

mainControl