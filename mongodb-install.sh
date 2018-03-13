#!/bin/bash
#mongodb installation script
#version mongodb 3.4
#date 2017-12-26

YumDir=/etc/yum.repo.d

MongodbYum(){

cat > $YumDir/mongodb.sh << "EOF" 
[mongodb-org-3.4]
name=MongoDB Repository
baseurl=http://repo.mongodb.org/yum/redhat/$releasever/mongodb-org/3.4/x86_64/
gpgcheck=0
enabled=1
#gpgkey=https://www.mongodb.org/static/pgp/server-3.4.asc
EOF
}

MongodbInstall(){
	yum install -y mongodb-org
	systemctl is-enabled mongod
	systemctl start mongod
}


MongodbYum && MongodbInstall
