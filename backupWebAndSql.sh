MYSQL_USER=root                         # mysql用户名
MYSQL_PASS=mg888888                     # mysql密码
MAIL_TO=huige@protonmail.ch             # 数据库发送到的邮箱
MAIL_TO2=nginx11724@qq.com
WEB_DATA=/data/wwwroot/myBlog/                 # 要备份的网站数据
BACKUP_SQL_NAME=lapuxixi                # 需要备份的数据库名称

FTP_USER=cat                            # ftp用户名
FTP_PASS=123456                         # ftp密码
FTP_IP=imcat.in                         # ftp地址
FTP_backup=backup                       # ftp上存放备份文件的目录,这个要自己得ftp上面建的
# 你要修改的地方从这里结束

if [ ! -d "/home/backup" ];then
    mkdir -p /home/backup
fi

# 定义数据库的名字和旧数据库的名字
DataBakName=Data_$(date +"%Y%m%d").tar.gz
WebBakName=Web_$(date +%Y%m%d).tar.gz
OldData=Data_$(date -d -5day +"%Y%m%d").tar.gz
OldWeb=Web_$(date -d -5day +"%Y%m%d").tar.gz

# 删除本地5天前的数据
rm -rf /home/backup/Data_$(date -d -5day +"%Y%m%d").tar.gz /home/backup/Web_$(date -d -5day +"%Y%m%d").tar.gz
cd /home/backup

# 导出数据库,一个数据库一个压缩文件
/usr/local/mysql/bin/mysqldump  -h127.0.0.1 -u$MYSQL_USER -p$MYSQL_PASS --databases ${BACKUP_SQL_NAME} -l  | gzip -9 - > ${BACKUP_SQL_NAME}_$(date +"%Y%m%d").sql.gz
# for db in `/usr/local/mysql/bin/mysql -u$MYSQL_USER -p$MYSQL_PASS -B -N -e 'SHOW DATABASES' | xargs`; do
#     (/usr/local/mysql/bin/mysqldump -u$MYSQL_USER -p$MYSQL_PASS  ${db} -l | gzip -9 - > ${db}_$(date +"%Y%m%d").sql.gz)
# done

# 压缩数据库文件为一个文件
# tar zcf /home/backup/$DataBakName /home/backup/*.sql.gz
# rm -rf /home/backup/*.sql.gz

# 压缩网站数据
tar zcf /home/backup/$WebBakName $WEB_DATA

# 发送数据库到Email,如果数据库压缩后太大,请注释这行
# echo "主题:数据库备份" | mutt -a /home/backup/$DataBakName -s "内容:数据库备份" $MAIL_TO
echo " 【拉普公会】:数据库备份文件" | mutt -s "【拉普公会】:数据库备份-"$(date +"%Y%m%d") $MAIL_TO -a ${BACKUP_SQL_NAME}_$(date +"%Y%m%d").sql.gz &&
echo " 【拉普公会】:Web备份文件" | mutt -s "【拉普公会】:Web备份-"$(date +"%Y%m%d") $MAIL_TO2 -a /home/backup/$WebBakName

# 上传到FTP空间,删除FTP空间5天前的数据
# ftp -v -n $FTP_IP << END
# user $FTP_USER $FTP_PASS
# type binary
# cd $FTP_backup
# delete $OldData
# delete $OldWeb
# put $DataBakName
# put $WebBakName
# bye
# END
