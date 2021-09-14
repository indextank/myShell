#!/bin/bash
#
#   Copyright (c) HJZD All Rights Reserved.
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Filename    ：backup_db_tmk.sh
#   Author      : Eric
#   Date        : 2018-10-19
#   Version     : 1.0
#   Description : 助销系统数据库备份
#   History     :
#                1> 初始版本 1.0
#
# 使用：crontab
# 59 23 * * * /usr/local/shell/mysql-backup/shell/backup_db_tmk.sh -backup -b tmk Hjzd@hf123 &
#============================================================================


usage()
{
    cat << !

 Usage: $G_SHELL_FILE [ help | -h | -g | -p | -s | -o]
 ----------------------------------------------------------------------------

    初始化用户环境
	----+--------------------------------------
        help |: 显示本帮助
	----+--------------------------------------
        -h   |: 显示本帮助
	----+--------------------------------------
	----+----------------------------------------
	-backup 
	     |-b  | : 从后台执行，由程序调用，送参数
	     |-m  | : 手工执行脚本，看按提示输入要素
	----+----------------------------------------
	-recover
	     |-b  | : 从后台执行，由程序调用，送参数
	     |-m  | : 手工执行脚本，看按提示输入要素
	----+----------------------------------------
		  | 用来还原数据文件(格式：.sql.gz)
	----+----------------------------------------

 ----------------------------------------------------------------------------
                               Copyright (C), HJZD All Rights Reserved.

!
}


#**********
# Function: Check Program Parameter
#****************************************************************************
chk_param()
{
    # show usage
    [ $# -eq 0 ] && return 1;
    [ $# -eq 1 ] && [ "$1" = "help" ] && return 1;
    [ $LOGNAME != $G_EXEC_USER ] && echo "ERROR: 本命令仅能在$G_EXEC_USER用户下使用" && return 1;
	G_COMMAND=""
	G_SUB_COMMND=""
    while [ ! "$1" = "" ] && [ $1 != -- ]; do
        case $1 in
	     -backup) 
		G_COMMAND="BK"
		while [ ! "$2" = "" ] && [ $2 != -- ]; do
			case $2 in 
			  -b) # 程序调用
			      if [ "$#" -lt 4 ] ; then
				    echo '***********************************'
				    echo $0 ':输入要备份的数据库3->SID,4->PWD'
				    echo '***********************************'
			            return 1;
			      else 
				   mysqlPwd=$4
			      fi
				return 0
				;;
			  -m) # 手工执行
				return 0
				;;
			  *)
			  ;;
			esac
		done
		return 0
		;;
	    -recover) #数据库恢复
		G_COMMAND="RC"
		while [ ! "$2" = "" ] && [ $2 != -- ]; do
			case $2 in 
			  -b) # 程序调用
			      if [ "$#" -lt 4 ] ; then
				    echo '*************************************************'
				    echo $0 ':输入要备份的数据库SID,还原数据文件名(.sql.gz)'
				    echo '*************************************************'
			            return 1;
			      fi
				return 0
				;;
			  -m) # 手工执行
				return 0
				;;
			  *)
			  ;;
			esac
		done

		return 0
		;;	
            -h)     # 显示帮助
                return 1
                ;;
            *) 
		echo "输入有错误，请重新输入！"
                ;;
        esac

        shift   # next flag
    done

	[ "$G_COMMAND" = "" ] && return 1;

    return 0
}


#**********
# Function: Init Shell
#****************************************************************************
init_sh()
{
    #保留最近100天备份
    #备份目录
    backupDir=/usr/local/shell/mysql-backup/data/daily/tmk

    backupLogDir=/usr/local/shell/mysql-backup/logs

    ####################################
    ######初始化参数区域################
    backupLogFile=daily_backup_db_tmk.log
    mysqldump=/usr/bin/mysqldump
    username=root
    host=192.168.66.52
    mysqlPwd=Hjzd@hf123
    ####################################

    #今天日期
    today=`date +%Y%m%d`

    #100天前的日期
    timeHudDayAgo=`date -d -100day +%Y%m%d`
    timeTenDayAgo=`date -d -10day +%Y%m%d`

    return 0
}

#**********
# Function: Exit Shell
#
# Parameter:
#       P1 : Exit Code
#****************************************************************************
exit_sh()
{
    EXIT_CODE=$1


    exit $EXIT_CODE
}



#**********
# Function: Execute Shell
#****************************************************************************
exec_sh()
{
if [ "$G_COMMAND" = "BK" ]; then
echo "$3"
#要备份的数据库数组
databases=($3)

[ ! -d $backupDir ] && mkdir -p $backupDir
echo '进程:备份日期['$today'],备份目录['$backupDir']' >> $backupLogDir/$backupLogFile

for database in ${databases[@]}
  do
    echo '-----开始备份'$database >> $backupLogDir/$backupLogFile
    $mysqldump -h$host -u$username -p$mysqlPwd --force $database | gzip > $backupDir/$database-$today.sql.gz
    echo '-----成功执行'$host $mysqlPwd'备份'$database'到'$backupDir/$database-$today.sql.gz >> $backupLogDir/$backupLogFile
    if [ -f "$backupDir/$database-$timeHudDayAgo.sql.gz" ]; then
        rm -f $backupDir/$database-$timeHudDayAgo.sql.gz 
        [ $? -ne 0 ] && echo '删除100天前备份文件失败' >> $backupLogDir/$backupLogFile
        echo '-----删除100天前备份文件成功'$backupDir/$database-$timeHudDayAgo.sql.gz >> $backupLogDir/$backupLogFile
    else
        echo '-----没有发现100天前的备份数据文件' >> $backupLogDir/$backupLogFile
    fi
  done

if [ -f "$backupDir/$database-$timeTenDayAgo.sql.gz" ]; then
    rm -f $backupDir/$database-$timeTenDayAgo.sql.gz 
    echo '-----删除10天前备份文件成功'$backupDir/$database-$timeTenDayAgo.sql.gz >> $backupLogDir/$backupLogFile
else
    echo '-----没有发现10天前备份文件' >> $backupLogDir/$backupLogFile
fi
echo '进程:备份日期['$today'],备份目录['$backupDir']完成!!!' >> $backupLogDir/$backupLogFile

return 0
elif [ "$G_COMMAND" = "RC" ]; then
    echo "$3"
    dbname="$3"
    backupFile="$4"  # 恢复数据库文件名.sql.gz
    if [ -f "$backupDir/$backupFile" ]; then
      gzip -d $backupDir/$backupFile && echo "解压成功"$backupDir/$backupFile >> $backupLogDir/$backupLogFile
      mysql -h$host -u$username -p$mysqlPwd $3 -e "source $backupDir/$backupFile"
      [ $? -eq 0 ] && echo '恢复数据库'$3'成功!!!' >> $backupLogDir/$backupLogFile
    fi
fi
}


#**********
# Main Program
#*********************************************************
G_SHELL_FILE=$0
G_SHELL_ARGC=$#
G_SHELL_ARGV=$*

#*********************************************************
#*****默认指定本脚本执行用户******************************
G_EXEC_USER=$LOGNAME



# Check shell parameter
chk_param $*
[ $? -ne 0 ] && usage && exit_sh -1


# Init shell
init_sh $*
[ $? -ne 0 ] && exit_sh 1


# Execute shell
exec_sh $*
exit_sh $#


