#! /bin/bash
#centos7.4源码编译Jumpserver安装脚本

chmod -R 777 /usr/local/src/jumpserver
#1、时间时区同步，修改主机名
ntpdate cn.pool.ntp.org
hwclock --systohc
echo "*/30 * * * * root ntpdate -s 3.cn.poop.ntp.org" >> /etc/crontab

sed -i 's|SELINUX=.*|SELINUX=disabled|' /etc/selinux/config
sed -i 's|SELINUXTYPE=.*|#SELINUXTYPE=targeted|' /etc/selinux/config
sed -i 's|SELINUX=.*|SELINUX=disabled|' /etc/sysconfig/selinux 
sed -i 's|SELINUXTYPE=.*|#SELINUXTYPE=targeted|' /etc/sysconfig/selinux
setenforce 0 && systemctl stop firewalld && systemctl disable firewalld 
setenforce 0 && systemctl stop iptables && systemctl disable iptables

rm -rf /var/run/yum.pid 
rm -rf /var/run/yum.pid
#一、-----------------------------------安装jumpserver--------------------------------------------------
#1）解决依赖关系
#yum -y install epel-release  
#yum -y install zlib-devel bzip2-devel openssl-devel ncurses-devel sqlite-devel readline-devel tk-devel gdbm-devel db4-devel libpcap-devel xz-devel gcc gcc-c++ git python-pip  automake autoconf python-devel sshpass readline-devel libffi-devel  

cd /usr/local/src/jumpserver/rpm
rpm -ivh /usr/local/src/jumpserver/rpm/*.rpm --force --nodeps

#yum -y install redis
sed -i 's|appendonly no|appendonly yes|' /etc/redis.conf 
sed -i 's|daemonize no|daemonize yes|' /etc/redis.conf 
systemctl start redis 
systemctl enable redis

#yum -y install mariadb mariadb-devel mariadb-server
systemctl start mariadb 
systemctl enable mariadb
mysql -uroot -e "create database jumpserver default charset 'utf8';"  
mysql -uroot -e "grant all on jumpserver.* to 'jumpserver'@'127.0.0.1' identified by 'Jumpserver6688';"  
mysql -uroot -e "flush privileges;" 


#2)编译安装python3.6
#groupadd jumpserver
#useradd -g jumpserver -s /sbin/nologin jumpserver
cd /usr/local/src/jumpserver
#wget https://www.python.org/ftp/python/3.6.4/Python-3.6.4.tar.xz 
mkdir -pv /usr/local/python
tar -xvf Python-3.6.4.tar.xz  -C /usr/local/python
cd /usr/local/python/Python-3.6.4/
./configure --prefix=/usr/local/python
make -j 2
make install
#二进制程序：
echo 'export PATH=/usr/local/python/bin:$PATH' > /etc/profile.d/python.sh 
source /etc/profile.d/python.sh
#头文件输出给系统：
ln -sv /usr/local/python/include /usr/include/python
#库文件输出：
echo '/usr/local/python/lib' > /etc/ld.so.conf.d/python.conf
#让系统重新生成库文件路径缓存
ldconfig
#导出man文件：
echo 'MANDATORY_MANPATH                       /usr/local/python/share/man' >> /etc/man_db.conf
source /etc/profile.d/python.sh 

#创建python虚拟环境 
cd /usr/local/python/
python3 -m venv py3 
source /usr/local/python/py3/bin/activate

#3)安装Jumpserver  
#cd /usr/local/
#git clone https://github.com/jumpserver/jumpserver.git 
cd /usr/local/src/jumpserver/
cp -r jumpserver /usr/local/
cd /usr/local/jumpserver/requirements/
#yum -y install $(cat rpm_requirements.txt)
pip3.6 install -r requirements.txt
pip3.6 install -r requirements.txt
pip3.6 install -r requirements.txt
cd /usr/local/jumpserver/
cp config_example.py config.py 
sed -i "s|# DB_ENGINE = 'mysql'|DB_ENGINE = 'mysql'|" /usr/local/jumpserver/config.py
sed -i "s|# DB_HOST = '127.0.0.1'|DB_HOST = '127.0.0.1'|" /usr/local/jumpserver/config.py
sed -i "s|# DB_PORT = 3306|DB_PORT = 3306|" /usr/local/jumpserver/config.py
sed -i "s|# DB_USER = 'root'|DB_USER = 'jumpserver'|" /usr/local/jumpserver/config.py
sed -i "s|# DB_PASSWORD = ''|DB_PASSWORD = 'Jumpserver6688'|" /usr/local/jumpserver/config.py
sed -i "s|# DB_NAME = 'jumpserver'|DB_NAME = 'jumpserver'|" /usr/local/jumpserver/config.py

sed -i 's|logfile "/opt/jumpserver/logs/redis.log"|logfile "/var/log/redis/redis.log"|' /usr/local/jumpserver/utils/redis.conf
sed -i 's|dir /opt/jumpserver/|dir "/var/lib/redis"|' /usr/local/jumpserver/utils/redis.conf

cd /usr/local/jumpserver/utils/
sh make_migrations.sh 
cd /usr/local/jumpserver
nohup python -u run_server.py all  > nohup.out 2>&1 & 

#打开浏览器访问: http://IP:8080 看到下面页面 ，使用用户名admin和密码admin
#ssh-keygen生成公钥cat /root/.ssh/id_rsa.pub 复制到ssh公钥。

#4)安装 SSH Server: Coco
source /usr/local/python/py3/bin/activate
cd /usr/local/src/jumpserver
#git clone https://github.com/jumpserver/coco.git
cp -r coco /usr/local/jumpserver
cd /usr/local/jumpserver/coco/requirements
#yum -y  install $(cat rpm_requirements.txt)
pip install -r requirements.txt
pip install -r requirements.txt
pip install -r requirements.txt
# 查看配置文件并运行
cd /usr/local/jumpserver/coco
cp conf_example.py conf.py 
cat conf.py 
nohup python -u run_server.py all  > nohup.out 2>&1 & 
#这时需要去 jumpserver管理后台-应用程序-终端接受coco的注册
#测试连接 密码: admin 如果能登陆代表部署成功
#ssh -p2222 admin@192.168.244.144
#ssh admin@192.168.244.144 2222

#5)安装 Web Terminal: Luna
source /usr/local/python/py3/bin/activate
cd /usr/local/src/jumpserver
#git clone https://github.com/jumpserver/luna.git
tar -zxvf luna.tar.gz -C /opt
chown -R root:root /opt/luna/
mkdir -pv /opt/jumpserver
cp -r /usr/local/jumpserver/data/ /opt/jumpserver/
#yum -y install nginx
#修改nginx配置文件配置适用于版本：v0.5.0
cat >> /etc/nginx/conf.d/jumpserver.conf <<EOF
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name jumpserver.ytzhihui.com;
    root /usr/share/nginx/html;

    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header Host $host;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
     
    location /luna/ {
        try_files $uri //index.html;
        alias /opt/luna/;
    }
 
    location /media/ {
        add_header Content-Encoding gzip;
        root /opt/jumpserver/data/;
    }
 
    location /static/ {
        root /opt/jumpserver/data/;
    }
 
    location /socket.io/ {
        proxy_pass       http://localhost:5000/socket.io/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
 
    location / {
        proxy_pass http://localhost:8080;
    }
}
EOF
systemctl daemon-reload 
systemctl enable nginx.service
systemctl restart nginx.service
#同样去jumpserver管理后台接受luna注册应用程序-终端 接受  运行nginx访问 http://localhost/luna/
#升级 jumpserver
#cd /usr/local/jumpserver && source/usr/local/python/py3/bin/activate
#git pull && cd utils && sh make_migrations.sh
#升级 coco
#git pull && cd requirements && pip install -r requirements.txt
#升级 luna访问 https://github.com/jumpserver/luna/releases，下载对应release包

#mkdir -pv /usr/local/jumpserver/users/ && cd /usr/local/jumpserver/users/ && ssh-keygen -f admin

#rm -rf /usr/local/src/jumpserver
