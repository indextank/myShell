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
/usr/libexec/iptables/iptables.init save && systemctl restart iptables
