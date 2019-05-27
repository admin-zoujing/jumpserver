#! /bin/bash
#centos7.4源码编译Jumpserver安装脚本
#安装文档 http://docs.jumpserver.org/zh/docs/setup_by_centos.html

chmod -R 777 /usr/local/src/jumpserver
#1、时间时区同步，修改主机名
ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
ntpdate ntp1.aliyum.com
hwclock --systohc
echo "*/30 * * * * root ntpdate -s ntp1.aliyum.com" >> /etc/crontab

sed -i 's|SELINUX=.*|SELINUX=disabled|' /etc/selinux/config
sed -i 's|SELINUXTYPE=.*|#SELINUXTYPE=targeted|' /etc/selinux/config
sed -i 's|SELINUX=.*|SELINUX=disabled|' /etc/sysconfig/selinux 
sed -i 's|SELINUXTYPE=.*|#SELINUXTYPE=targeted|' /etc/sysconfig/selinux
firewall-cmd --zone=public --add-port=80/tcp --permanent
firewall-cmd --zone=public --add-port=2222/tcp --permanent
firewall-cmd --reload
setenforce 0

rm -rf /var/run/yum.pid 
rm -rf /var/run/yum.pid
#一、-----------------------------------安装Python3--------------------------------------------------
#一. 准备 Python3 和 Python 虚拟环境
#1）YUM安装python3.6
yum -y install wget gcc epel-release git
yum -y install python36 python36-devel
cd /opt
python3.6 -m venv py3 
source /opt/py3/bin/activate
echo 'export PATH=/opt/py3/bin:$PATH' > /etc/profile.d/python.sh 
source /etc/profile.d/python.sh
# 如果下载速度很慢, 可以换国内源
# wget -O /etc/yum.repos.d/epel.repo http://mirrors.aliyun.com/repo/epel-7.repo
# yum -y install python36 python36-devel

#2)编译安装python3.6
#groupadd jumpserver
#useradd -g jumpserver -s /sbin/nologin jumpserver
#cd /usr/local/src/jumpserver
#wget https://www.python.org/ftp/python/3.6.4/Python-3.6.4.tar.xz 
#mkdir -pv /usr/local/python
#tar -xvf Python-3.6.4.tar.xz  -C /usr/local/python
#cd /usr/local/python/Python-3.6.4/
#./configure --prefix=/usr/local/python --enable-optimizations
#make -j 2
#make install

#echo 'export PATH=/usr/local/python/bin:$PATH' > /etc/profile.d/python.sh 
#source /etc/profile.d/python.sh
#ln -sv /usr/local/python/include /usr/include/python
#echo '/usr/local/python/lib' > /etc/ld.so.conf.d/python.conf
#ldconfig
#echo 'MANDATORY_MANPATH                       /usr/local/python/share/man' >> /etc/man_db.conf
#source /etc/profile.d/python.sh 

#创建python虚拟环境 
#cd /usr/local/python/
#python3.6 -m venv py3 
#source /opt/py3/bin/activate

#二、-----------------------------------安装Jumpserver--------------------------------------------------
#二. 安装 Jumpserver
#1)安装Jumpserver  

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


cd /opt/
git clone --depth=1 https://github.com/jumpserver/jumpserver.git
cd /opt/jumpserver/requirements/
yum -y install $(cat rpm_requirements.txt)

pip install --upgrade pip setuptools
pip install -r requirements.txt
pip install future==0.16.0
cd /opt/jumpserver/
cp config_example.yml config.yml 

SECRET_KEY=`cat /dev/urandom | tr -dc A-Za-z0-9 | head -c 50`
echo "SECRET_KEY=$SECRET_KEY" >> ~/.bashrc
BOOTSTRAP_TOKEN=`cat /dev/urandom | tr -dc A-Za-z0-9 | head -c 16`
echo "BOOTSTRAP_TOKEN=$BOOTSTRAP_TOKEN" >> ~/.bashrc

sed -i "s|SECRET_KEY:|SECRET_KEY: $SECRET_KEY|" /opt/jumpserver/config.yml
sed -i "s|BOOTSTRAP_TOKEN:|BOOTSTRAP_TOKEN: $BOOTSTRAP_TOKEN|" /opt/jumpserver/config.yml
sed -i "s|# DEBUG: true|DEBUG: false|" /opt/jumpserver/config.yml
sed -i "s|# LOG_LEVEL: DEBUG|LOG_LEVEL: ERROR|" /opt/jumpserver/config.yml
sed -i "s|# SESSION_EXPIRE_AT_BROWSER_CLOSE: false|SESSION_EXPIRE_AT_BROWSER_CLOSE: true|" /opt/jumpserver/config.yml
sed -i "s|DB_PASSWORD:|DB_PASSWORD: Jumpserver6688|" /opt/jumpserver/config.yml
sed -i "s|# REDIS_PASSWORD:|REDIS_PASSWORD: sanxin|" /opt/jumpserver/config.yml
echo -e "\033[31m 你的SECRET_KEY是 $SECRET_KEY \033[0m"
echo -e "\033[31m 你的BOOTSTRAP_TOKEN是 $BOOTSTRAP_TOKEN \033[0m"

#./jms start all -d 
cat > /usr/lib/systemd/system/jms.service <<EOF
[Unit]
Description=jms
After=network.target mariadb.service redis.service
Wants=mariadb.service redis.service

[Service]
Type=forking
Environment="PATH=/opt/py3/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/root/bin"
ExecStart=/opt/jumpserver/jms start all -d
ExecReload=
ExecStop=/opt/jumpserver/jms stop

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload 
systemctl enable jms.service
systemctl start jms.service
systemctl status jms.service


#三、-----------------------------------安装WebSocket Server: Coco----------------------------------------------
#三. 安装 SSH Server 和 WebSocket Server: Coco
#1 下载或 Clone 项目
cd /opt
source /opt/py3/bin/activate
git clone --depth=1 https://github.com/jumpserver/coco.git

#2 安装依赖
cd /opt/coco/requirements
yum -y install $(cat rpm_requirements.txt)
pip install -r requirements.txt
# 如果下载速度很慢, 可以换国内源
# pip install -r requirements.txt -i https://mirrors.aliyun.com/pypi/simple/

#3 修改配置文件并运行
cd /opt/coco
cp config_example.yml config.yml
sed -i "s|BOOTSTRAP_TOKEN: <PleasgeChangeSameWithJumpserver>|BOOTSTRAP_TOKEN: $BOOTSTRAP_TOKEN|" /opt/coco/config.yml
sed -i "s|# LOG_LEVEL: INFO|LOG_LEVEL: ERROR|" /opt/coco/config.yml
#./cocod start -d
cat > /usr/lib/systemd/system/coco.service <<EOF
[Unit]
Description=coco
After=network.target jms.service

[Service]
Type=forking
PIDFile=/opt/coco/coco.pid
Environment="PATH=/opt/py3/bin"
ExecStart=/opt/coco/cocod start -d
ExecReload=
ExecStop=/opt/coco/cocod stop

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload 
systemctl enable coco.service
systemctl start coco.service
systemctl status coco.service

#四、-----------------------------------安装WebSocket Server: Coco----------------------------------------------
#四. 安装 Web Terminal 前端: Luna
#Luna 已改为纯前端, 需要 Nginx 来运行访问
#1 解压 Luna
cd /opt
wget https://github.com/jumpserver/luna/releases/download/1.4.10/luna.tar.gz
tar xf luna.tar.gz
chown -R root:root luna
# 如果网络有问题导致下载无法完成可以使用下面地址
# wget https://demo.jumpserver.org/download/luna/1.4.10/luna.tar.gz

#五、-----------------------------------安装 Windows 支持组件----------------------------------------------
#五. 安装 Windows 支持组件(如果不需要管理 windows 资产, 可以直接跳过这一步)
#1 安装依赖
rpm --import http://li.nux.ro/download/nux/RPM-GPG-KEY-nux.ro
rpm -Uvh http://li.nux.ro/download/nux/dextop/el7/x86_64/nux-dextop-release-0-5.el7.nux.noarch.rpm
yum -y localinstall --nogpgcheck https://download1.rpmfusion.org/free/el/rpmfusion-free-release-7.noarch.rpm https://download1.rpmfusion.org/nonfree/el/rpmfusion-nonfree-release-7.noarch.rpm

yum install -y java-1.8.0-openjdk libtool
yum install -y cairo-devel libjpeg-turbo-devel libpng-devel uuid-devel
yum install -y ffmpeg-devel freerdp-devel freerdp-plugins pango-devel libssh2-devel libtelnet-devel libvncserver-devel pulseaudio-libs-devel openssl-devel libvorbis-devel libwebp-devel ghostscript

#2 编译安装 guacamole 服务
cd /opt
git clone --depth=1 https://github.com/jumpserver/docker-guacamole.git
cd /opt/docker-guacamole/
tar -xf guacamole-server-0.9.14.tar.gz
cd guacamole-server-0.9.14
autoreconf -fi
./configure --with-init-dir=/etc/init.d
make && make install
ln -s /usr/local/lib/freerdp/*.so /usr/lib64/freerdp/
cd ..
rm -rf guacamole-server-0.9.14
ldconfig

#3 配置 Tomcat
mkdir -p /config/guacamole /config/guacamole/lib /config/guacamole/extensions  
ln -sf /opt/docker-guacamole/guacamole-auth-jumpserver-0.9.14.jar /config/guacamole/extensions/guacamole-auth-jumpserver-0.9.14.jar
ln -sf /opt/docker-guacamole/root/app/guacamole/guacamole.properties /config/guacamole/guacamole.properties  

cd /config
wget http://mirrors.tuna.tsinghua.edu.cn/apache/tomcat/tomcat-8/v8.5.40/bin/apache-tomcat-8.5.40.tar.gz
tar xf apache-tomcat-8.5.40.tar.gz
rm -rf apache-tomcat-8.5.40.tar.gz
mv apache-tomcat-8.5.40 tomcat8
rm -rf /config/tomcat8/webapps/*
ln -sf /opt/docker-guacamole/guacamole-0.9.14.war /config/tomcat8/webapps/ROOT.war  
sed -i 's/Connector port="8080"/Connector port="8081"/g' /config/tomcat8/conf/server.xml  
sed -i 's/FINE/WARNING/g' /config/tomcat8/conf/logging.properties  

cd /config
wget https://github.com/ibuler/ssh-forward/releases/download/v0.0.5/linux-amd64.tar.gz
tar xf linux-amd64.tar.gz -C /bin/
chmod +x /bin/ssh-forward
# 如果网络有问题导致下载无法完成可以使用下面地址
# wget https://demo.jumpserver.org/download/ssh-forward/v0.0.5/linux-amd64.tar.gz

#4 配置环境变量
# 勿多次执行以下环境设置
export JUMPSERVER_SERVER=http://127.0.0.1:8080  
echo "export JUMPSERVER_SERVER=http://127.0.0.1:8080" >> ~/.bashrc
export JUMPSERVER_KEY_DIR=/config/guacamole/keys
echo "export JUMPSERVER_KEY_DIR=/config/guacamole/keys" >> ~/.bashrc
export GUACAMOLE_HOME=/config/guacamole
echo "export GUACAMOLE_HOME=/config/guacamole" >> ~/.bashrc
#export BOOTSTRAP_TOKEN=$BOOTSTRAP_TOKEN
#echo "export BOOTSTRAP_TOKEN=$BOOTSTRAP_TOKEN" >> ~/.bashrc

#5 启动 Guacamole
/etc/init.d/guacd start
#sh /config/tomcat8/bin/startup.sh
chkconfig guacd on
cat > /usr/lib/systemd/system/guacamole.service <<EOF
[Unit]
Description=guacamole
After=network.target jms.service
Wants=jms.service

[Service]
Type=forking
# PIDFile=/config/tomcat8/tomcat.pid
# BOOTSTRAP_TOKEN 根据实际情况修改
Environment="JUMPSERVER_SERVER=http://127.0.0.1:8080" "JUMPSERVER_KEY_DIR=/config/guacamole/keys" "GUACAMOLE_HOME=/config/guacamole" "BOOTSTRAP_TOKEN=$BOOTSTRAP_TOKEN"
ExecStart=/config/tomcat8/bin/startup.sh
ExecReload=
ExecStop=/config/tomcat8/bin/shutdown.sh

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload 
systemctl enable guacamole.service
systemctl start guacamole.service
systemctl status guacamole.service

#六、-----------------------------------安装Nginx----------------------------------------------
#六. 配置 Nginx 整合各组件
#1 安装 Nginx
yum -y install yum-utils
echo '
[nginx-stable]
name=nginx stable repo
baseurl=http://nginx.org/packages/centos/$releasever/$basearch/
gpgcheck=1
enabled=1
gpgkey=https://nginx.org/keys/nginx_signing.key
' > /etc/yum.repos.d/nginx.repo

yum makecache fast
yum install -y nginx
rm -rf /etc/nginx/conf.d/default.conf
systemctl enable nginx

#2 准备配置文件 修改 /etc/nginx/conf.d/jumpserver.conf
echo '
server {
    listen 80;  # 代理端口, 以后将通过此端口进行访问, 不再通过8080端口
    # server_name demo.jumpserver.org;  # 修改成你的域名或者注释掉

    #client_max_body_size 100m;  # 录像及文件上传大小限制

    location /luna/ {
        try_files $uri / /index.html;
        alias /opt/luna/;  # luna 路径, 如果修改安装目录, 此处需要修改
    }

    location /media/ {
        add_header Content-Encoding gzip;
        root /opt/jumpserver/data/;  # 录像位置, 如果修改安装目录, 此处需要修改
    }

    location /static/ {
        root /opt/jumpserver/data/;  # 静态资源, 如果修改安装目录, 此处需要修改
    }

    location /socket.io/ {
        proxy_pass       http://localhost:5000/socket.io/;  # 如果coco安装在别的服务器, 请填写它的ip
        proxy_buffering off;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        access_log off;
    }

    location /coco/ {
        proxy_pass       http://localhost:5000/coco/;  # 如果coco安装在别的服务器, 请填写它的ip
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        access_log off;
    }

    location /guacamole/ {
        proxy_pass       http://localhost:8081/;  # 如果guacamole安装在别的服务器, 请填写它的ip
        proxy_buffering off;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection $http_connection;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        access_log off;
    }

    location / {
        proxy_pass http://localhost:8080;  # 如果jumpserver安装在别的服务器, 请填写它的ip
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}
' > /etc/nginx/conf.d/jumpserver.conf

#3 运行 Nginx
nginx -t   
systemctl start nginx
systemctl enable nginx
systemctl status nginx
#4 开始使用 Jumpserver
#服务全部启动后, 访问http://IP, 访问nginx代理的端口, 不要再通过8080端口访问
#默认账号: admin 密码: admin
#到Jumpserver 会话管理-终端管理 检查 Coco Guacamole 等应用的注册。

#测试连接
#如果登录客户端是 macOS 或 Linux, 登录语法如下
#ssh -p2222 admin@192.168.244.144
#sftp -P2222 admin@192.168.244.144
#密码: admin

#如果登录客户端是 Windows, Xshell Terminal 登录语法如下
#ssh admin@192.168.244.144 2222
#sftp admin@192.168.244.144 2222
#密码: admin
#如果能登陆代表部署成功

# sftp默认上传的位置在资产的 /tmp 目录下
# windows拖拽上传的位置在资产的 Guacamole RDP上的 G 目录下

