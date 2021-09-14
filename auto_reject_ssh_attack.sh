#! /bin/bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

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
WHITE_IP_LIST=('36.7.71.106' '139.224.199.198')

command -v lsb_release >/dev/null 2>&1 || {
  echo "${CFAILURE}${PM} source failed! ${CEND}"
  kill -9 $$
}

# Get OS Version
OS=$(lsb_release -is)
if [[ "${OS}" =~ ^CentOS$|^CentOSStream$|^RedHat$|^Rocky$|^Fedora$|^Amazon$|^Alibaba$|^Aliyun$|^EulerOS$|^openEuler$ ]]; then
  LikeOS=CentOS
  CentOS_ver=$(lsb_release -rs | awk -F. '{print $1}' | awk '{print $1}')
  [[ "${OS}" =~ ^Fedora$ ]] && [ ${CentOS_ver} -ge 19 ] >/dev/null 2>&1 && {
    CentOS_ver=7
    Fedora_ver=$(lsb_release -rs)
  }
  [[ "${OS}" =~ ^Amazon$|^Alibaba$|^Aliyun$|^EulerOS$|^openEuler$ ]] && CentOS_ver=7
elif [[ "${OS}" =~ ^Debian$|^Deepin$|^Uos$|^Kali$ ]]; then
  LikeOS=Debian
  Debian_ver=$(lsb_release -rs | awk -F. '{print $1}' | awk '{print $1}')
  [[ "${OS}" =~ ^Deepin$|^Uos$ ]] && [[ "${Debian_ver}" =~ ^20$ ]] && Debian_ver=10
  [[ "${OS}" =~ ^Kali$ ]] && [[ "${Debian_ver}" =~ ^202 ]] && Debian_ver=10

  if [ -f "/etc/update-motd.d/10-uname" ]; then
    sed -i "s@uname -snrvm@#uname -snrvm@" /etc/update-motd.d/10-uname
  fi
elif [[ "${OS}" =~ ^Ubuntu$|^LinuxMint$|^elementary$ ]]; then
  LikeOS=Ubuntu
  Ubuntu_ver=$(lsb_release -rs | awk -F. '{print $1}' | awk '{print $1}')
  if [[ "${OS}" =~ ^LinuxMint$ ]]; then
    [[ "${Ubuntu_ver}" =~ ^18$ ]] && Ubuntu_ver=16
    [[ "${Ubuntu_ver}" =~ ^19$ ]] && Ubuntu_ver=18
    [[ "${Ubuntu_ver}" =~ ^20$ ]] && Ubuntu_ver=20
  fi
  if [[ "${OS}" =~ ^elementary$ ]]; then
    [[ "${Ubuntu_ver}" =~ ^5$ ]] && Ubuntu_ver=18
    [[ "${Ubuntu_ver}" =~ ^6$ ]] && Ubuntu_ver=20
  fi
fi

# Check OS Version
if [ ${CentOS_ver} -lt 6 ] >/dev/null 2>&1 || [ ${Debian_ver} -lt 8 ] >/dev/null 2>&1 || [ ${Ubuntu_ver} -lt 16 ] >/dev/null 2>&1; then
  echo "${CFAILURE}Does not support this OS, Please install CentOS 6+,Debian 8+,Ubuntu 16+ ${CEND}"
  kill -9 $$
fi

# 为截取secure文件恶意ip 远程登录22端口，大于等于3次就写入防火墙 禁止再登录服务器22端口。
# egrep -o "([0-9]{1,3}\.){3}[0-9]{1,3}" 匹配IP. [0-9]表示任意一个数 {1,3}表示匹配1~3次
# IP_ADDR=$(tail -n 1000 /var/log/secure | grep "Failed password" | egrep -o "([0-9]{1,3}\.){3}[0-9]{1,3}" | sort -nr | uniq -c | awk '$1>='$DEFINE' {print $2}')
cat /var/log/secure | awk '/Failed password/{print $(NF-3)}' | sort | uniq -c | awk '{print $2"="$1;}' >$IP_BLACK

green "========= 获取到非法入侵IP列表 =============="
cat $IP_BLACK
green "=============================================\n"
# sleep 2s

blue "禁止sshd登录、iptables..."
for i in $(cat $IP_BLACK); do
  IP_ADDR=$(echo | awk '{split("'${i}'", array, "=");print array[1]}')
  NUM=$(echo | awk '{split("'${i}'", array, "=");print array[2]}')
  if [[ ! "${WHITE_IP_LIST[@]}" =~ "${IP_ADDR}" ]]; then

    if [ $NUM -gt $DEFINE ]; then
      grep $IP_ADDR /etc/hosts.deny >/dev/null
      if [ $? -gt 0 ]; then
        echo "sshd:$IP_ADDR:deny" >>/etc/hosts.deny
      fi

      # 查看iptables配置文件是否含有提取的IP信息
      grep $IP_ADDR /etc/sysconfig/iptables >/dev/null
      # 判断iptables配置文件中是否存在已拒绝的IP，不存在，则添加，存在，则不添加。sed 【i:表示在匹配行前加入; a:表示在匹配行后加入】
      if [ $? -gt 0 ]; then
        /sbin/iptables -I INPUT -s $IP_ADDR -j DROP
        # sed -i "/lo/i -A INPUT -s $IP_ADDR -j DROP" /etc/sysconfig/iptables
      fi
    fi
  fi
done

# 重启防火墙配置生效
if [ ${CentOS_ver} -eq 6 ]; then
  service iptables restart && /etc/rc.d/init.d/iptables save
else
  /usr/libexec/iptables/iptables.init save && systemctl restart iptables
fi

rm -fr auto_reject_ssh_attack.sh
