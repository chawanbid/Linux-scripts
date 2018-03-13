#!/bin/bash
#tomcat日志切割，每天一滚动
#author chawan 20170925

DATE=`date -d "1 day ago" +"%Y-%m-%d"`
TOMCAT=/usr/loca/tomcat
cd $TOMCAT

tar -Jcf $TOMCAT/logs/catalina.out$DATE.xz catalina.out

echo > $TOMCAT/logs/catalina.out

find $TOMCAT/logs -ctime +15 -exec rm -rf {} \;
