#!/bin/sh
src=/home/dailyBackUp/     # 需要同步的源路径
src2=/home/dailyBackUp/    # 需要监视的路径
des=web_105
user=webUser
rsync_passwd_file=/usr/local/rsync/rsync.passwd
des_ip="192.168.8.140"  # 备份目标服务器

#function
inotify_fun ()
{
    [ ! -d /home/dailyBackUp/ ] && mkdir -p /home/dailyBackUp/
    cd ${src}
    /usr/local/bin/inotifywait -mrq --format  '%Xe %w%f' -e modify,create,attrib,close_write,move ${src2} | while read file
    do
            INO_EVENT=$(echo $file | awk '{print $1}')
            INO_FILE=$(echo $file | awk '{print $2}')

            echo "-------------------------------$(date)------------------------------------"
            echo $file

            if [[ $INO_EVENT =~ 'CREATE' ]] || [[ $INO_EVENT =~ 'MODIFY' ]] || [[ $INO_EVENT =~ 'CLOSE_WRITE' ]] || [[ $INO_EVENT =~ 'MOVED_TO' ]]
            then
                    echo 'CREATE or MODIFY or CLOSE_WRITE or MOVED_TO'
                    for ip in $des_ip
                    do
                        echo "`date +%Y%m%d-%T`: rsync -avzq --delete --progress $1 root@$ip:$1"
                        /usr/bin/rsync -avzq --progress --password-file=${rsync_passwd_file} $1 ${user}@${ip}::${des}
                        echo "${files} was rsynced" >>/var/log/rsync.log 2>&1
                     done
            fi

            if [[ $INO_EVENT =~ 'ATTRIB' ]]
            then
                    echo 'ATTRIB'
                    if [ ! -d "$INO_FILE" ]
                    then
                        for ip in $des_ip
                        do
                            echo "`date +%Y%m%d-%T`: rsync -avzq --delete --progress $1 root@$ip:$1"
                            /usr/bin/rsync -avzq --progress --delete --password-file=${rsync_passwd_file} $1 ${user}@${ip}::${des}
                            echo "${files} was rsynced" >>/var/log/rsync.log 2>&1
                         done
                    fi
            fi
    done
}

#main
for a in $src
do
inotify_fun $a
done