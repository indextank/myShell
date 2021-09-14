#!/bin/bash

wget -c https://ftp.postgresql.org/pub/source/v9.4.5/postgresql-9.4.5.tar.gz
tar xzf postgresql-9.4.5.tar.gz
cd postgresql-9.4.5
./configure && make && make install

useradd postgres 
passwd postgres 

sed -i 's/postgres:x:502:502::\/home\/postgres:\/bin\/bash/postgres:x:502:502::\/usr\/local\/postgres:\/bin\/bash/g' /etc/passwd
cp /home/postgres/.bash_profile /usr/local/pgsql/.bash_profile
chown postgres.postgres .bash_profile
rm -rf /home/postgres

# 新建数据目录
mkdir -p /home/data/pgsql
chown -R postgres /home/data/pgsql/

touch /home/data/pgsql/.pgsql_history

echo "export PGDATA=/home/data/pgsql" >> /usr/local/pgsql/.bash_profile
echo "export PATH=/usr/local/pgsql/bin:$PATH" >> /usr/local/pgsql/.bash_profile
echo "export LANG=zh_CN.UTF-8" >> /usr/local/pgsql/.bash_profile
echo "export PGPORT=5432" >> /usr/local/pgsql/.bash_profile
source /usr/local/pgsql/.bash_profile

su - postgres

pg_ctl initdb 
pg_ctl start -l /home/data/pgsql/pgsql.log

vi /home/data/pgsql/pg_hba.conf
sed -i 's/sed host    all             all             127.0.0.1\/32            trust/sed host    all             all             0.0.0.0\/0            trust/g' /home/data/pgsql/pg_hba.conf
sed -i 's/#listen_addresses = 'localhost'/listen_addresses = '*'/g' /home/data/pgsql/postgresql.conf
sed -i 's/#port = 5432/port = 5432/g' /home/data/pgsql/postgresql.conf

/sbin/iptables -I INPUT -p tcp --dport 5432 -j ACCEPT
/etc/init.d/iptables save
/etc/init.d/iptables restart

#
cp contrib/start-scripts/linux /etc/init.d/postgresql
sed -i 's/PGDATA="\/usr\/local\/pgsql\/data"/PGDATA="\/home\/data\/pgsql"/g' /etc/init.d/postgresql
mkdir /usr/local/postgres
chmod +x /etc/init.d/postgresql
chkconfig --add postgresql
chkconfig postgresql on



