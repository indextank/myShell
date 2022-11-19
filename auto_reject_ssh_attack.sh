#! /bin/bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

## 非法入侵IP，连续三次错误，禁止ssh登录，并永久加入防火墙黑名单
## 支持配置白名单，防止自己密码错误此处达到3次导致无法登录

blue() {
  echo -e "\033[34m\033[01m$1\033[0m"
}
green() {
  echo -e "\033[32m\033[01m$1\033[0m"
}
red() {
  echo -e "\033[31m\033[01m$1\033[0m"
}
# auto drop ssh failded IP address

# 定义变量
SEC_FILE=/var/log/secure
IP_BLACK=/usr/local/src/black.txt

# 登录失败次数
DEFINE="3"

# 白名单
WHITE_IP_LIST=('36.7.71.106' '139.224.199.198' '139.196.203.197')

command -v lsb_release >/dev/null 2>&1 || {
  if [[ "${LikeOS}" == "CentOS" ]]; then
    yum -y install redhat-lsb-core
  elif [[ "${LikeOS}" =~ ^Ubuntu$|^Debian$ ]]; then
    apt-get -y install lsb-release
  fi
}

# Get OS Version ${$(lsb_release -is),,}
OS=$(lsb_release -is)
Platform=${OS,,}
VERSION_ID=$(lsb_release -rs | awk -F. '{print $1}' | awk '{print $1}')
if [[ "${Platform}" =~ ^centos$|^rhel$|^almalinux$|^rocky$|^fedora$|^amzn$|^ol$|^alinux$|^anolis$|^tencentos$|^euleros$|^openeuler$|^kylin$ ]]; then
  PM=yum
  Family=rhel
  if [[ "${Platform}" =~ ^centos$ ]]; then
    RHEL_ver=${VERSION_ID}
  elif [[ "${Platform}" =~ ^fedora$ ]]; then
    Fedora_ver=${VERSION_ID}
    [ ${VERSION_ID} -ge 19 ] && [ ${VERSION_ID} -lt 28 ] && RHEL_ver=7
    [ ${VERSION_ID} -ge 28 ] && [ ${VERSION_ID} -lt 34 ] && RHEL_ver=8
    [ ${VERSION_ID} -ge 34 ] && RHEL_ver=9
  elif [[ "${Platform}" =~ ^amzn$|^alinux$|^tencentos$|^euleros$ ]]; then
    [[ "${VERSION_ID}" =~ ^2$ ]] && RHEL_ver=7
    [[ "${VERSION_ID}" =~ ^3$ ]] && RHEL_ver=8
  elif [[ "${Platform}" =~ ^openeuler$ ]]; then
    [[ "${RHEL_ver}" =~ ^20$ ]] && RHEL_ver=7
    [[ "${RHEL_ver}" =~ ^2[1,2]$ ]] && RHEL_ver=8
  elif [[ "${Platform}" =~ ^kylin$ ]]; then
    [[ "${RHEL_ver}" =~ ^V10$ ]] && RHEL_ver=7
  fi
elif [[ "${Platform}" =~ ^debian$|^deepin$|^uos$|^kali$ ]]; then
  PM=apt-get
  Family=debian
  Debian_ver=${VERSION_ID}
  if [[ "${Platform}" =~ ^deepin$|^uos$ ]]; then
    [[ "${Debian_ver}" =~ ^20$ ]] && Debian_ver=10
    [[ "${Debian_ver}" =~ ^23$ ]] && Debian_ver=11
  elif [[ "${Platform}" =~ ^kali$ ]]; then
    [[ "${Debian_ver}" =~ ^202 ]] && Debian_ver=10
  fi
elif [[ "${Platform}" =~ ^ubuntu$|^linuxmint$|^elementary$ ]]; then
  PM=apt-get
  Family=ubuntu
  Ubuntu_ver=${VERSION_ID}
  if [[ "${Platform}" =~ ^linuxmint$ ]]; then
    [[ "${VERSION_ID}" =~ ^18$ ]] && Ubuntu_ver=16
    [[ "${VERSION_ID}" =~ ^19$ ]] && Ubuntu_ver=18
    [[ "${VERSION_ID}" =~ ^20$ ]] && Ubuntu_ver=20
    [[ "${VERSION_ID}" =~ ^21$ ]] && Ubuntu_ver=22
  elif [[ "${Platform}" =~ ^elementary$ ]]; then
    [[ "${VERSION_ID}" =~ ^5$ ]] && Ubuntu_ver=18
    [[ "${VERSION_ID}" =~ ^6$ ]] && Ubuntu_ver=20
    [[ "${VERSION_ID}" =~ ^7$ ]] && Ubuntu_ver=22
  fi
else
  echo "${CFAILURE}Does not support this OS ${CEND}"
  kill -9 $$; exit 1;
fi

# Check OS Version
if [ ${RHEL_ver} -lt 6 ] >/dev/null 2>&1 || [ ${Debian_ver} -lt 8 ] >/dev/null 2>&1 || [ ${Ubuntu_ver} -lt 16 ] >/dev/null 2>&1; then
    echo "${CFAILURE}Does not support this OS, Please install CentOS 6+,Debian 8+,Ubuntu 16+ ${CEND}"
    kill -9 $$; exit 1;
fi

if [ `grep -c "HISTCONTROL=ignorespace" ~/.bashrc` -eq  '0' ]; then
  echo HISTCONTROL=ignorespace >> ~/.bashrc 
  source ~/.bashrc
fi

# 为截取secure文件恶意ip 远程登录22端口，大于等于3次就写入防火墙 禁止再登录服务器22端口。
# egrep -o "([0-9]{1,3}\.){3}[0-9]{1,3}" 匹配IP. [0-9]表示任意一个数 {1,3}表示匹配1~3次
# IP_ADDR=$(tail -n 1000 /var/log/secure | grep "Failed password" | egrep -o "([0-9]{1,3}\.){3}[0-9]{1,3}" | sort -nr | uniq -c | awk '$1>='$DEFINE' {print $2}')

if [ -f "/var/log/secure" ]; then
    cat /var/log/secure | awk '/Failed password/{print $(NF-3)}' | sort | uniq -c | awk '{print $2"="$1;}' >$IP_BLACK
elif [ -f "/var/log/auth.log" ]; then
    cat /var/log/auth.log | awk '/Failed password/{print $(NF-3)}' | sort | uniq -c | awk '{print $2"="$1;}' >$IP_BLACK
fi

green "========= 获取到非法入侵IP列表 =============="
cat $IP_BLACK
green "=============================================\n"
# sleep 2s

blue "禁止sshd登录、完成非法入侵IP加入防火墙黑名单"
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

                # nftables防火墙
                if [ -f "/usr/sbin/nft" ];then
                  grep $IP_ADDR /etc/nftables.conf >/dev/null
                  if [ $? -gt 0 ]; then
                     nft insert rule inet filter input ip saddr $IP_ADDR drop
                  fi
                else
                # iptables防护墙
                    /sbin/service iptables status 1>/dev/null 2>&1
                    if [ $? -eq 0 ]; then
                        # 查看iptables配置文件是否含有提取的IP信息
                        grep $IP_ADDR /etc/sysconfig/iptables >/dev/null
                        # 判断iptables配置文件中是否存在已拒绝的IP，不存在，则添加，存在，则不添加。sed 【i:表示在匹配行前加入; a:表示在匹配行后加入】
                        if [ $? -gt 0 ]; then
                            /sbin/iptables -I INPUT -s $IP_ADDR -j DROP
                            # sed -i "/lo/i -A INPUT -s $IP_ADDR -j DROP" /etc/sysconfig/iptables
                        fi
                    fi
                fi
            fi
        fi
    done

    # 重启防火墙配置生效
    # nftables防火墙
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
else
    echo "系统很安全."
fi
rm -fr auto_reject_ssh_attack.sh ${IP_BLACK}

# firewalld 防火墙： 拉黑IP
# firewall-cmd --permanent --add-rich-rule='rule family=ipv4 source address="192.168.0.23" drop' 
# firewall-cmd --reload
