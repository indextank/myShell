#!/bin/bash

#保留最近100天备份
#备份目录
backupDir=/home/dailyBackUp/105_sqlBackUp

#mysqlDump
mysqldump=/usr/local/mariadb/bin/mysqldump
host=127.0.0.1
username=root
#password=hjzd@hf123

#今天日期
today=`date +%Y%m%d`

#100天前的日期
timeHudDayAgo=`date -d -100day +%Y%m%d`
timeTenDayAgo=`date -d -10day +%Y%m%d`

#要备份的数据库数组
databases=(ccds credit_card feedback ks_telesale met_db mindoc_db nx_telesale opm risk xinhu_db)

for database in ${databases[@]}
  do
    echo '开始备份'$database
    # $mysqldump -h$host -u$username -p$password --force $database | gzip > $backupDir/$database-$today.sql.gz
    $mysqldump -h$host -u$username -phjzd@hf123 --force $database | gzip > /home/dailyBackUp/105_sqlBackUp/$database-$today.sql.gz
    echo '成功备份'$database'到'$backupDir/$database-$today.sql.gz >> dailyBackLog.log
    if [ -f "$backupDir/$database-$timeHudDayAgo.sql.gz" ]; then
        rm -f $backupDir/$database-$timeHudDayAgo.sql.gz
        echo '删除100天前备份文件'$backupDir/$database-$timeHudDayAgo.sql.gz >> dailyBackLog.log
    fi
  done

# 备份整个mariadb目录
/etc/init.d/mysqld stop
tar cjPf /home/dailyBackUp/105_sqlBackUp/all-$today.sql.gz /home/mariadb-data/*
echo '成功备份mariadb-data整个目录到'$backupDir/all-$today.sql.gz >> dailyBackLog.log
/etc/init.d/mysqld start

if [ -f "$backupDir/all-$timeTenDayAgo.sql.gz" ]; then
    rm -f $backupDir/$database-$timeTenDayAgo.sql.gz
    echo '删除10天前备份文件'$backupDir/$database-$timeTenDayAgo.sql.gz >> dailyBackLog.log
fi