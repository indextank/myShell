#! /bin/bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

wget --no-check-certificate https://raw.githubusercontent.com/indextank/myShell/master/auto_reject_ssh_attack.sh
chmod +x auto_reject_ssh_attack.sh
./auto_reject_ssh_attack.sh >>auto_reject_ssh_attack.log
