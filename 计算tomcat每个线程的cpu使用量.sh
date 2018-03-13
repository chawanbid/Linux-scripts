#!/bin/bash
#通过jstack 列出java线程信息使用awk将每个线程的cpu使用率添加在每个线程的后面
#time 2018-03-13 author chawan
#email  chawan21@126.com

 
typeset top=${1:-10}
typeset pid=${2:-$(pgrep -u $USER java)}
typeset tmp_file=/tmp/java_${pid}_$$.trace
 
$JAVA_HOME/bin/jstack $pid > $tmp_file
ps H -eo user,pid,ppid,tid,time,%cpu --sort=%cpu --no-headers\
        | tail -$top\
        | awk -v "pid=$pid" '$2==pid{print $4"\t"$6}'\
        | while read line;
do
        typeset nid=$(echo "$line"|awk '{printf("0x%x",$1)}')
        typeset cpu=$(echo "$line"|awk '{print $2}')
        awk -v "cpu=$cpu" '/nid='"$nid"'/,/^$/{print $0"\t"(isF++?"":"cpu="cpu"%");}' $tmp_file
done
 
rm -f $tmp_file