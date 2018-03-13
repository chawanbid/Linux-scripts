#!/bin/bash
#mariadb安装脚本版本10.0


MariadbYum(){
	cat > /etc/yum.repos.d/MariaDB.repo <<EOF
# MariaDB 10.0 CentOS repository list - created 2015-02-06 05:28 UTC
# http://mariadb.org/mariadb/repositories/
[mariadb]
name = MariaDB
baseurl = http://yum.mariadb.org/10.0/centos7-amd64
gpgkey=https://yum.mariadb.org/RPM-GPG-KEY-MariaDB
gpgcheck=1
EOF
}

MariadbInstall(){
sudo -i
yum install MariaDB-server MariaDB-client

systemctl is-enable mariadb
systemctl start mariadb

#'/usr/bin/mysqladmin' -u root password 'new-password'
#'/usr/bin/mysqladmin' -u root -h localhost.localdomain password 'new-password'
#'/usr/bin/mysql_secure_installation'

cp /etc/my.cnf{,.original}
cp /etc/my.cnf.d/server.cnf{,.original}
cp /etc/my.cnf.d/client.cnf{,.original}

sed -i '10iskip-name-resolve' /etc/my.cnf.d/server.cnf 
sed -i '11imax_connections=8192' /etc/my.cnf.d/server.cnf
sed -i '12idefault-storage-engine=INNODB' /etc/my.cnf.d/server.cnf
sed -i '13iwait_timeout=30' /etc/my.cnf.d/server.cnf
sed -i '14iinteractive_timeout=30' /etc/my.cnf.d/server.cnf
sed -i '15icharacter-set-server=utf8' /etc/my.cnf.d/server.cnf
sed -i '16icollation_server=utf8_general_ci' /etc/my.cnf.d/server.cnf
sed -i "17iinit_connect='SET NAMES utf8'" /etc/my.cnf.d/server.cnf
sed -i '18iexplicit_defaults_for_timestamp=true' /etc/my.cnf.d/server.cnf

sed -i '5icharacter_set_client=utf8' /etc/my.cnf.d/client.cnf 


}

FirewallMariadb(){
	iptables -A INPUT -m state --state NEW -m tcp -p tcp --dport 3306 -j ACCEPT
	service iptables save
}
deploy(){
clear
echo "################MaridbInstall脚本工具################"
echo "#                                                   #"
echo "#            0.自动配置yum源并安装mariadb           #"
echo "#            1.安装Maridb-server MariaDB-client     #"
echo "#            2.如果防火墙开启则开通3306端口         #"
echo "#            3.退出                                 #"
echo "#####################################################"
read -p "请输入选项:" ID
case $ID in
0)
MariadbYum&&MariadbInstall
;;
1)
MariadbInstall
;;
2)
FirewallMariadb
;;
3)
exit 0
;;	
*)
echo "输入不合法，请重新输入检测输入信息"  && deploy
;;
esac
}
deploy