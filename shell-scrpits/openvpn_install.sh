#!/bin/bash
#Description: install openvpn and create server certificate
#Version: 1.0
#Date: 2017-08-30
#Author: kongxiangwen
#Email: 981651697@qq.com

args=$#
vpn_path=$1
rsa_path=$2
script_dir=$(cd `dirname $0`; pwd) #获取脚本当前路径
. /etc/init.d/functions

devel_pkg_check(){  #检测必要软件包的安装
	if [ -f "/etc/redhat-release" ];then
		for i in `echo -e "gcc\nopenssl-devel\nlzo-devel\npam-devel\nexpect"`;do
			if ! rpm -qa| grep -q $i;then
				echo "$i 未安装"
				exit 1
			fi
		done
	else
		echo "只支持CentOS系列"
	fi
}

check(){ #格式化输出结果
	if [ $? -ne 0 ];then
		action "$1" /bin/false
		exit 100
	else
		action "$1" /bin/true
	fi 
}

unzip_pkg(){ 	#解压包
	if ! echo $1 | grep -Eq '\.tar\.[2a-z]*$|\.zip$';then
		echo "Package Error(包解压只支持 zip tar.×)"
		exit 2
	fi

	if [ "$2" == '2' ];then 	#检测easy-rsa 包版本是否为2.x
		if ! unzip -v $1 | grep -q '/easy-rsa/2.0/';then
			echo "找不到$rsa_path/easy-rsa/2.0/ 目录,仅支持easy-rsa-2.x，请使用easy-rsa 2.x版本"
			exit 3
		fi
	fi
	
	if echo $1 | grep -Eq '\.tar\.[2a-z]*$';then
		tar -xf $1
		check "解压 $1" 
		vpn_src_dir=`tar -tf $1  | head -n 1`
		if [ -d "/usr/local/${vpn_src_dir}" ];then
			echo "/usr/local/${vpn_src_dir} 目录已存在"
			exit 1
		fi
	elif echo $1 | grep -Eq '\.zip$';then
		unzip -o $1 > /dev/null
		check "解压 $1"
		rsa_src_dir=`unzip -l $1 | head -n 5| tail -n 1| awk '{print $4}'`
	fi

}

file_check(){	
	if [ $args -ne 2 ];then		#参数个数检测
		echo "Usage: Script.sh openvpn-Package  easy-rsa-FILE"
		exit 1
	fi

	if ! echo $vpn_path | grep -qi 'openvpn';then		#openvpn包名检测
		echo '第一个参数应包含openvpn字符串'
        echo "Usage: Script.py openvpn-Package easy-rsa-FILE"
		exit 1
	fi

	if ! [ -f $vpn_path ];then 		#检测openvpn-Package是否存在
		echo "$vpn_path 文件不存在"
		exit 1
	elif ! [ -f $rsa_path ];then		##检测easy-rsa-FILE是否存在
		echo "$rsa_path 文件不存在"
		exit 1
	fi
}
var_args_check(){	#证书基本信息检测函数
	var_args=$3
	while true;do
		if [ -z $var_args ];then
			read -p "输入为空，重新输入 $1" $2
			var_args=`eval echo '$'"$2"`
		else
			break
		fi
	done
	
}

var_args_check_server(){  #服务器证书名输入检测
	var_args=$3
	KEY_CONN=`cat ${script_dir}/${rsa_src_dir}easy-rsa/2.0/vars | grep -o 'KEY_CN=.*$'|sed 's/KEY_CN=//'`
	while true;do
		if [ -z $var_args ];then
        	read -p "输入为空，重新输入 $1" $2
        	var_args=`eval echo '$'"$2"`
		elif echo "${KEY_CONN}" | grep -Eq "\<$var_args\>" ;then
			read -p "证书名已存在，重新输入 $1" $2
			var_args=`eval echo '$'"$2"`
		else
			break
		fi
	done
}

vars_init(){   #输入ca基本信息 ，存入vars文件
	echo
	echo '请输入要创建的CA证书信息:'
	while true;do
		read -p '国家(countryName): ' KEY_COUNTRY
		if [ "`echo -n $KEY_COUNTRY | wc -c`" -ne 2 ];then
			echo 'it needs to be at least 2 bytes long'
			continue
		else
			break
		fi
	done
	read -p '省份(provinceName): ' KEY_PROVINCE
	var_args_check  '省份(provinceName): ' 'KEY_PROVINCE' ${KEY_PROVINCE} 
	read -p '城市(city): ' KEY_CITY
	var_args_check '城市(city): ' KEY_CITY $KEY_CITY
	read -p '公司(org): ' KEY_ORG
	var_args_check '公司(org): ' KEY_ORG $KEY_ORG
	read -p '邮箱(email): ' KEY_EMAIL
	var_args_check '邮箱(email): ' KEY_EMAIL $KEY_EMAIL
	read -p '部门(section): ' KEY_OU
	var_args_check '部门(section): ' KEY_OU $KEY_OU
	read -p '名字(name): ' KEY_NAME
	var_args_check '名字(name): ' KEY_NAME $KEY_NAME
	read -p '唯一证书名(commonName): ' KEY_CN 
	var_args_check '唯一证书名(commonName): ' KEY_CN $KEY_CN 
	cd ${rsa_src_dir}easy-rsa/2.0/
	for i in `echo -e "KEY_COUNTRY\nKEY_PROVINCE\nKEY_CITY\nKEY_ORG\nKEY_EMAIL\nKEY_OU\nKEY_NAME\nKEY_CN\n"`;do
		sed -i "s/$i=.*/$i=`eval echo '$'"$i"`/" ./vars
	done
}

build_ca(){  #使用expect模块创建ca ，自动输入ca信息
	. ./vars > /dev/null
	. ./clean-all
	/usr/bin/expect  << EOF
	log_user 0
	set timeout 5
	spawn ./build-ca
	expect "Country Name" {send "${KEY_COUNTRY}\r"}
	expect "State or Province Name" {send "${KEY_PROVINCE}\r"}
	expect "Locality Name" {send "${KEY_CITY}\r"}
	expect "Organization Name" {send "${KEY_ORG}\r"}
	expect "Organizational Unit Name" {send "${KEY_OU}\r"}
	expect "Common Name" {send "${KEY_CN}\r"}
	expect "Name" {send "${KEY_NAME}\r"}
	expect "Email Address" {send "${KEY_EMAIL}\r"}
	expect "timeout" {puts "build-ca error"; exit 1 }
EOF
	check "CA证书生成"
}

build_key_server(){ #使用expect模块创建server证书，自动输入信息
	echo
	read -p '输入服务器证书名(需唯一): ' KEY_SERVER_NAME
	var_args_check_server '输入服务器证书名(需唯一): ' KEY_SERVER_NAME $KEY_SERVER_NAME 
	read -p '输入服务器证书密码(可为空): ' KEY_SERVER_PASSWD
	/usr/bin/expect << EOF
	log_user 0
	set timeout 5
	spawn ./build-key-server server
	expect "Country Name" {send "${KEY_COUNTRY}\r"}
	expect "State or Province Name" {send "${KEY_PROVINCE}\r"}
	expect "Locality Name" {send "${KEY_CITY}\r"}
	expect "Organization Name" {send "${KEY_ORG}\r"}
	expect "Organizational Unit Name" {send "${KEY_OU}\r"}
	expect "Common Name" {send "${KEY_SERVER_NAME}\r"}
	expect "Name" {send "${KEY_NAME}\r"}
	expect "Email Address" {send "${KEY_EMAIL}\r"}
	expect "password" {send "${KEY_SERVER_PASSWD}\r"}
	expect "company name" {send "${KEY_ORG}\r"}
	expect "y/n" {send "y\r"}
	expect "y/n" {send "y\r"}
	expect "timeout" { puts "error"; exit 1 }
EOF
	check "Server 证书生成"
	echo "# Custom Content----------------------------------------" >> ./vars
	echo "# KEY_SERVER_NAME=${KEY_SERVER_NAME}" >> ./vars
	echo "# KEY_SERVER_PASSWD=${KEY_SERVER_PASSWD}" >> ./vars
	echo "# KEY_CLIENT_NAME=" >> ./vars
}

install_openvpn(){ 	#编译安装openvpn
	cd ${script_dir}/${vpn_src_dir}
	./configure --prefix=/usr/local/${vpn_src_dir} &> /dev/null
	echo
	check "执行 ./configure --prefix=/usr/local/${vpn_src_dir}"
	make > /dev/null
	check "执行 make"
	make install > /dev/null
	check "执行 make install"
	cp -r ${script_dir}/${rsa_src_dir}easy-rsa /usr/local/${vpn_src_dir}
	check "安装目录为 /usr/local/${vpn_src_dir}"
}
DF_TLS_KEY(){ #生成生成迪菲·赫尔曼交换密钥
	cd /usr/local/${vpn_src_dir}easy-rsa/2.0/
	. ./vars &> /dev/null
	./build-dh &> /dev/null
	echo
	[ $? -eq 0 ] && check "生成迪菲·赫尔曼交换密钥" || { check "生成迪菲·赫尔曼交换密钥" ; exit 5; }
	/usr/local/${vpn_src_dir}sbin/openvpn   --genkey --secret keys/ta.key

}

create_server_conf(){ #创建server端配置文件以及目录
	cd /usr/local/${vpn_src_dir}
	mkdir config
	cd ./easy-rsa/2.0/keys/
	cp ca.crt ca.key dh2048.pem server.crt server.key ta.key /usr/local/${vpn_src_dir}config
	echo
	echo "本机地址如下："
	ip a | grep -E "^[0-9]|^[[:space:]]*inet "  | sed 's/<.*//'| grep -Eo '^[0-9].*|inet [0-9./]*' | tr '\n' ' '| sed -r 's# [0-9]*:#\n&#g' | sed 's/^[[:space:]]*//'  #输出本地所有网卡及ip信息
	echo
	while true;do
		read -p "输入服务端监听的ip地址：" IP   #可在/usr/local/${vpn_src_dir}config/server.conf中修改
		if [ "`echo $IP | sed -r 's/((25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9][0-9]?)//g'`" != "" ];then
			echo "IP输入错误,重新输入"
			continue
		else
			break
		fi
	done
	echo
	echo "指定虚拟局域网占用的IP地址段和子网掩码:" #可在/usr/local/${vpn_src_dir}config/server.conf中修改
	read -p "例(10.0.0.0 255.255.255.0): " NETMASK
#创建server.conf配置文件
cat << EOF >> /usr/local/${vpn_src_dir}config/server.conf 
local $IP     #指定监听的本机IP(因为有些计算机具备多个IP地址)，该命令是可选的，默认监听所有IP地址。
port 1194             #指定监听的本机端口号
proto udp             #指定采用的传输协议，可以选择tcp或udp
dev tun               #指定创建的通信隧道类型，可选tun或tap
ca ca.crt             #指定CA证书的文件路径
cert server.crt       #指定服务器端的证书文件路径
key server.key    #指定服务器端的私钥文件路径
dh dh2048.pem         #指定迪菲赫尔曼参数的文件路径
server $NETMASK   #指定虚拟局域网占用的IP地址段和子网掩码，此处配置的服务器自身占用10.0.0.1。
ifconfig-pool-persist ipp.txt   #服务器自动给客户端分配IP后，客户端下次连接时，仍然采用上次的IP地址(第一次分配的IP保存在ipp.txt中，下一次分配其中保存的IP)。
tls-auth ta.key 0     #开启TLS-auth，使用ta.key防御攻击。服务器端的第二个参数值为0，客户端的为1。
keepalive 10 120      #每10秒ping一次，连接超时时间设为120秒。
comp-lzo              #开启VPN连接压缩，如果服务器端开启，客户端也必须开启
client-to-client      #允许客户端与客户端相连接，默认情况下客户端只能与服务器相连接
persist-key
persist-tun           #持久化选项可以尽量避免访问在重启时由于用户权限降低而无法访问的某些资源。
status openvpn-status.log    #指定记录OpenVPN状态的日志文件路径
verb 3                #指定日志文件的记录详细级别，可选0-9，等级越高日志内容越详细
EOF

}

client_sh_check(){ #客户端脚本存在性检测
	echo 
	echo "启动方法：cd /usr/local/${vpn_src_dir}config ; /usr/local/${vpn_src_dir}sbin/openvpn server.conf &"
	echo
	[ -f $script_dir/openvpn_create_client_certificate.sh ] || { action "当前目录下openvpn_create_client_certificate.sh 检测" /bin/false; echo ; echo "请将openvpn_create_client_certificate.sh置于/usr/local/${vpn_src_dir}下"; exit 200; }
	cp $script_dir/openvpn_create_client_certificate.sh /usr/local/${vpn_src_dir}
	echo "创建客户端的脚本路径为/usr/local/${vpn_src_dir}openvpn_create_client_certificate.sh"
}

main(){
devel_pkg_check
file_check
unzip_pkg $rsa_path 2
unzip_pkg $vpn_path
vars_init
build_ca
build_key_server
install_openvpn
DF_TLS_KEY
create_server_conf
echo
check "安装配置openvpn服务端"
client_sh_check

}

main
