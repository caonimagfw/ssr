#!/bin/bash
# bash sethost.sh xxx.net aa.xxx.net 80 passwd

#Set Caddy 
# /usr/local/caddy/Caddyfile
set_caddy_80()
{

	#back file 
	#copy 
	rm -rf /usr/local/caddy/Caddyfile.bak_fuck
	mv /usr/local/caddy/Caddyfile /usr/local/caddy/Caddyfile.bak_fuck
	rm -rf /usr/local/caddy/Caddyfile
	cat <<EOF>  /usr/local/caddy/Caddyfile
		:443 {
			root /usr/local/caddy/www
			timeouts none
			tls /root/ssl/{$domain}/cert.pem /root/ssl/{$domain}}/privkey.pem
			gzip
		}

		:8099 {
			redir https://{$subdomain}{uri}
		}
EOF

}

set_caddy_443()
{
	#back file 
	#copy 
	rm -rf /usr/local/caddy/Caddyfile.bak_fuck
	mv /usr/local/caddy/Caddyfile /usr/local/caddy/Caddyfile.bak_fuck
	rm -rf /usr/local/caddy/Caddyfile
	cat <<EOF>  /usr/local/caddy/Caddyfile
		:8100 {
			root /usr/local/caddy/www
			timeouts none
			tls /root/ssl/{$domain}/cert.pem /root/ssl/{$domain}}/privkey.pem
			gzip
		}

		:80 {
			redir https://{$subdomain}{uri}
		}
EOF

}

#Set Fuck Wall Config 
#/etc/shadowsocks.json
set_config_80()
{
	#back file 
	#copy 
	rm -rf /etc/shadowsocks.json.bak_fuck
	mv /etc/shadowsocks.json /etc/shadowsocks.json.bak_fuck
	rm -rf /etc/shadowsocks.json
	cat <<EOF>  /etc/shadowsocks.json
	{
	    "server":"0.0.0.0",
	    "server_ipv6":"[::]",
	    "server_port":80,
	    "local_address":"127.0.0.1",
	    "local_port":1080,
	    "password":"$pwd",
	    "timeout":120,
	    "method":"none",
	    "protocol":"auth_chain_a",
	    "protocol_param":"",
	    "obfs":"plain",
	    "obfs_param":"",
	    "redirect":["*:80#127.0.0.1:8099"],
	    "dns_ipv6":true,
	    "fast_open":false,
	    "workers":10
	}
EOF
}

set_config_443()
{
	#back file 
	#copy 
	rm -rf /etc/shadowsocks.json.bak_fuck
	mv /etc/shadowsocks.json /etc/shadowsocks.json.bak_fuck
	rm -rf /etc/shadowsocks.json
	cat <<EOF>  /etc/shadowsocks.json
	{
	    "server":"0.0.0.0",
	    "server_ipv6":"[::]",
	    "server_port":443,
	    "local_address":"127.0.0.1",
	    "local_port":1080,
	    "password":"$pwd",
	    "timeout":120,
	    "method":"none",
	    "protocol":"auth_chain_a",
	    "protocol_param":"",
	    "obfs":"plain",
	    "obfs_param":"",
	    "redirect":["*:443#127.0.0.1:8100"],
	    "dns_ipv6":true,
	    "fast_open":false,
	    "workers":10
	}
EOF
}

#args
domain=$1
subdomain=$2
method=$3
pwd=$4

[ -z $1 ] && [ -z $2 ] && [ -z $3 ] && [ -z $4 ]
case "$method" in
    80|443)
        set_caddy_$method()
        set_config_$method()
        echo "new Caddyfile :"
        cat /usr/local/caddy/Caddyfile

        echo "new Fuck Wall Config :"
        cat /etc/shadowsocks.json
        service caddy stop 
        systemctl restart shadowsocks
        service caddy start 
        echo "Setting done, Fuck FangBX"
        ;;
    *)
        echo "Arguments error! [${action}]"
        echo "Usage: `basename $0` [xxx.net ab.xxx.net 80 pwd || xxx.net ab.xxx.net 443 pwd]"
        ;;
esac

exit 0