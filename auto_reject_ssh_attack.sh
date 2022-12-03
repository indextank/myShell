#! /bin/bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

IP_BLACK=/usr/local/src/black.txt
DEFINE="5"
WHITE_IP_LIST=('36.7.120.26', '36.7.71.106' '139.224.199.198' '139.196.203.197', '47.52.151.237', '39.100.151.214', '8.210.51.228', '8.212.11.246')

if [ `grep -c "HISTCONTROL=ignorespace" ~/.bashrc` -eq  '0' ]; then
  echo HISTCONTROL=ignorespace >> ~/.bashrc
  source ~/.bashrc
fi

touch ${IP_BLACK}

if [ -f "/var/log/secure" ]; then
    cat /var/log/secure | awk '/Failed password/{print $(NF-3)}' | sort | uniq -c | awk '{print $2"="$1;}' > $IP_BLACK
elif [ -f "/var/log/auth.log" ]; then
    cat /var/log/auth.log | awk '/Failed password/{print $(NF-3)}' | sort | uniq -c | awk '{print $2"="$1;}' > $IP_BLACK
fi

if [ -f "/var/log/messages" ]; then
    cat /var/log/messages | awk '/\[WARNING\] Authentication failed for user/{print $(NF-6)}' | tr -d '(?@)[WARNING]' | sort | sed '/^$/d' | uniq -c | awk '{print $2"="$1;}' >> $IP_BLACK
fi

echo "========= 获取到非法入侵IP列表 =============="
cat $IP_BLACK
echo "=============================================\n"
# sleep 2s

echo "禁止sshd登录、完成非法入侵IP加入防火墙黑名单"
if [ -s $IP_BLACK ]; then
    for i in $(cat $IP_BLACK); do
        IP_ADDR=$(echo | awk '{split("'${i}'", array, "=");print array[1]}')
        NUM=$(echo | awk '{split("'${i}'", array, "=");print array[2]}')
        if [[ ! "${WHITE_IP_LIST[@]}" =~ "${IP_ADDR}" ]]; then

            if [ $NUM -gt $DEFINE ]; then
                grep $IP_ADDR /etc/hosts.deny >/dev/null
                if [ $? -gt 0 ]; then
                  echo "sshd:$IP_ADDR:deny" >>/etc/hosts.deny
                fi

                if [ -e "/usr/sbin/iptables" ]; then
                    if [ -e "/usr/sbin/nft" ];then
                      grep $IP_ADDR /etc/nftables.conf >/dev/null
                      if [ $? -gt 0 ]; then
                         nft insert rule inet filter input ip saddr $IP_ADDR drop
                      fi
                    else
                        /sbin/service iptables status 1>/dev/null 2>&1
                        if [ $? -eq 0 ]; then
                            grep $IP_ADDR /etc/sysconfig/iptables >/dev/null
                            if [ $? -gt 0 ]; then
                                /sbin/iptables -I INPUT -s $IP_ADDR -j DROP
                                # sed -i "/lo/i -A INPUT -s $IP_ADDR -j DROP" /etc/sysconfig/iptables
                            fi
                        fi
                    fi
                fi
            fi
        fi
    done

    if [ -f "/etc/nftables.conf" ];then
      nft list ruleset > /etc/nftables.conf
    else
        /sbin/service iptables status 1>/dev/null 2>&1
        if [ $? -eq 0 ]; then
            if [ ${CentOS_ver} -eq 6 ]; then
              /etc/rc.d/init.d/iptables save && service iptables restart
            else
              /usr/libexec/iptables/iptables.init save && systemctl restart iptables
            fi
        fi
    fi
fi
rm -fr auto_reject_ssh_attack.sh ${IP_BLACK}
