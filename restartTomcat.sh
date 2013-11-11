
#!/bin/bash
# Function:自动监控tomcat脚本并且执行重启操作
# Author:Yu Chao
# E-mail:yuchao@ucfgroup.com
# Date:11/01/2013
# */5 * * * * su - root -c /root/restartTomcat.sh
# 该脚本不能放到TOMCAT_HOME根目录下，否则容易导致定时任务进程出错。
# if you want switch other user executed the script 
# please use the command su - username -s /bin/bash your_shell.sh
# DEFINE

#单步调试
#set -x

#Upload文件路径
UPLOAD_PATH=/home/onlinepay/uploadwars

# 设置TOMCAT_HOME 
TOMCAT_HOME=/home/onlinepay/apache-tomcat-6.0.29

#端口号
TOMCAT_PORT=8080

# tomcat启动程序(这里注意tomcat实际安装的路径)
StartTomcat=${TOMCAT_HOME}/bin/startup.sh

# tomcat 工作目录，用于清空缓存
#TomcatCache=${TOMCAT_HOME}/work

# 日志输出
TomcatMonitorLog=/tmp/TomcatMonitor.log
# 备份目录
TOMCAT_BACK_UP=/home/onlinepay/backup
# 需要备份的文件目录
TOMCAT_WEBAPPS=$TOMCAT_HOME/webapps

# 备份文件夹 按照日期命名
NOW=`date +%s`
FILE_NAME=`date -d "1970-01-01 UTC $NOW seconds" +%Y%m%d%H%M`;
#FILE_NAME=`date +%y%m%d%H`
echo " Back up the Tomcat war file into the $FILE_NAME"

DIRE_DIR=$TOMCAT_BACK_UP/$FILE_NAME
#判断文件夹是否存在，存在则删除再创建
if [ -d "$DIRE_DIR" ] ;then
	rmdir "$DIRE_DIR"
	mkdir "$DIRE_DIR"
else
	mkdir "$DIRE_DIR"
fi
#需要备份的文件名字
FILE_NAME=$DIRE_DIR/chao_$FILE_NAME.tar.gz
echo "start backup $FILE_NAME at `date`"
#备份文件
tar zcvf  $FILE_NAME  $TOMCAT_WEBAPPS/*.war

echo "finish backup at `date`"

function reDeploy()
{
	#不删除的目录
	NoDelFile=("shopDemo" "shopDemo.war" "merchant_local.properties" "." "..")
	#遍历删除目录
	DeleteFile=("auto" "ecs" "manage" "pay" "user")
	#遍历删除war文件和文件夹 除了shopDemo目录，shopDemo.war和属性文件外
	for dir in ${TOMCAT_WEBAPPS}
	do
		filearr=$(ls $dir);
		for file in ${filearr[*]}
		do
			case $file in
				"shopDemo")
					continue;;
				"shopDemo.war")
					continue;;
				"merchant_local.properties")
					continue;;
				".")
					continue;;
				"..")
					continue;;
				*)
					rm -rf $file;;
			esac
		done
	done

	#部署文件
	echo "start cp the war path"
	cp -rf $UPLOAD_PATH/* $TOMCAT_WEBAPPS
	echo "cp war file successful "
}

RestartTomcat()
{
	# 获取tomcat进程ID
	TomcatID=$(ps -wef|grep tomcat |grep -v grep |grep $TOMCAT_HOME | awk ' { print $2 } ')
	echo "==`date`==RESTART================"
	echo "tomcat-originpid-$TomcatID"
	echo "[info]tomcat...[$(date +'%F %H:%M:%S')]"
	#获取tomcat进程ID数目
	pnum_server=`ps -wef|grep tomcat |grep -v grep |grep $TOMCAT_HOME|wc -l`
	echo "ps number is $pnum_server"
	if [[ $pnum_server ]] ;
	then
		$TOMCAT_HOME/bin/shutdown.sh
		#rm -rf ${TOMCAT_HOME}/work/*
		sleep 10s
		# 获取shutdown后的tomcat进程ID
		ShutdownID=$(ps -wef|grep tomcat |grep -v grep |grep $TOMCAT_HOME| awk ' { print $2 } ')
		echo "tomcat-shutdownpid-$ShutdownID"
		if [[ $ShutdownID ]]
		then
			echo "tomcat starting"
			kill -9 $ShutdownID
			tempTomcatID=$(ps -wef|grep tomcat |grep -v grep |grep $TOMCAT_HOME| awk ' { print $2 } ')
			if [[ $tempTomcatID ]]
			then
				echo "Shutdown failed"
				$TOMCAT_HOME/bin/shutdown.sh
			else
				reDeploy
				echo "Shutdown Successful"
				$TOMCAT_HOME/bin/startup.sh
			fi
		else
			reDeploy
			echo "tomcat no running"
			$TOMCAT_HOME/bin/startup.sh
		fi
		echo "------------------------------"
	else
		reDeploy
		$TOMCAT_HOME/bin/startup.sh
		#echo $TOMCAT_HOME/logs/catalina.out
	fi
	echo "==`date`==END================"
}
RestartTomcat>>$TomcatMonitorLog

exit 0