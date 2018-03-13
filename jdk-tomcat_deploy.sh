#!/bin/bash
#
#
#
SRC=/usr/local/src
LOCATE=/usr/local
JDK="jdk-8u91-linux-x64.gz"
JDK18="jdk1.8.0_91"
TOMCAT="apache-tomcat-7.0.67.tar.gz"
TOMCAT7="apache-tomcat-7.0.67"

jdk_deploy(){
tar xf $SRC/$JDK
mv $SRC/$JDK18  $LOCATE/jdk1.8
cat > /etc/profile.d/jdk1.8.sh << "EOF" 
JAVA_HOME=/usr/local/jdk1.8
JRE_HOME=$JAVA_HOME/jre
PATH=$PATH:$JAVA_HOME/bin:$JRE_HOME/bin
CLASSPATH=:$JAVA_HOME/lib/dt.jar:$JAVA_HOME/lib/tools.jar:$JRE_HOME/lib
export JAVA_HOME JRE_HOME PATH CLASSPATH
EOF
chmod +x /etc/profile.d/jdk1.8.sh
source /etc/profile.d/jdk1.8.sh
}

tomcat_deploy(){
tar xf $SRC/$TOMCAT
mv $SRC/$TOMCAT7 $LOCATE
cd $LOCATE
ln -s $TOMCAT7 tomcat
#为tomcat设置UTF-8编码
sed -i -e '/connectionTimeout="20000"/a\URIEncoding="UTF-8"' $LOCATE/tomcat/conf/server.xml
#为tomcat设置单独的环境变量路径，防止主机存在2个以上tomcat时启动出现冲突
sed -i -e '/\#\!\/bin\/sh/a\export TOMCAT_HOME=/usr/local/tomcat\nexport CATALINA_HOME=/usr/local/tomcat\nexport JRE_HOME=/usr/local/jdk1.8/jre\nexport JAVA_HOME=/usr/local/jdk1.8 
JAVA_OPTS="-Dfile.encoding=utf-8 -Duser.timezone=Asia/Shanghai"
export CATALINA_OPTS="$CATALINA_OPTS 
     -Dcom.sun.management.jmxremote=true
     -Dcom.sun.management.jmxremote.ssl=false
    -Dcom.sun.management.jmxremote.port=8090
    -Dcom.sun.management.jmxremote.authenticate=false
    -Djava.rmi.server.hostname=10.80.227.108" ' $LOCATE/tomcat/bin/catalina.sh
}
       
deploy(){
clear
echo "################众信普惠jdk与tomcat自动安装工具############"
echo "#                                                         #"
echo "#                    0.自动安装jdk与tomcat                #"
echo "#                    1.安装jdk                            #"
echo "#                    2.安装tomcat                         #"
echo "#                    3.退出                               #"
echo "###########################################################"
read -p "请输入选项:" ID
case $ID in
0)
jdk_deploy&&tomcat_deploy
;;
1)
jdk_deploy
;;
2)
tomcat_deploy
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