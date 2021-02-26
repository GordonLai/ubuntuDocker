FROM ubuntu:18.04

# 基本安裝
RUN apt-get -y update && apt-get -y upgrade \
&& apt-get install software-properties-common -y \
&& add-apt-repository ppa:ondrej/php -y \
&& add-apt-repository ppa:certbot/certbot -y \
&& apt-get update -y

# Add Language Packs
RUN apt-get install -y language-pack-zh-hans-base

# 設定時區
RUN apt-get update \
  && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends tzdata
    
RUN TZ=Asia/Taipei \
  && ln -snf /usr/share/zoneinfo/$TZ /etc/localtime \
  && echo $TZ > /etc/timezone \
  && dpkg-reconfigure -f noninteractive tzdata 

# Set the locale language
RUN sed -i -e 's/# zh_TW.UTF-8 UTF-8/zh_TW.UTF-8 UTF-8/' /etc/locale.gen && locale-gen
ENV LANG zh_TW.UTF-8  
ENV LANGUAGE zh_TW:en  
ENV LC_ALL zh_TW.UTF-8 

# 安裝基本套件
RUN apt-get install -y sudo vim wget curl zip unzip git ufw

# 安裝 Mysql Server
RUN echo 'mysql-server mysql-server/root_password password root' | debconf-set-selections
RUN echo 'mysql-server mysql-server/root_password_again password root' | debconf-set-selections
RUN DEBIAN_FRONTEND=noninteractive sudo apt-get -qq install -y mysql-server mysql-client > /dev/null
RUN sed -i "s/.*bind-address.*/bind-address = 0.0.0.0/" /etc/mysql/mysql.conf.d/mysqld.cnf

# 設定 Mysql Server 
RUN usermod -d /var/lib/mysql mysql \
&& mkdir -p /var/run/mysqld \
&& mkdir -p /var/lib/mysql \
&& chown mysql:mysql /var/run/mysqld \
&& chown mysql:mysql /var/lib/mysql \
&& chmod -R 777 /var/lib/mysql

ARG SQLFLOW_MYSQL_PORT="3306"
ENV SQLFLOW_MYSQL_PORT=$SQLFLOW_MYSQL_PORT
EXPOSE $SQLFLOW_MYSQL_PORT

# 安裝 Apache Server
RUN DEBIAN_FRONTEND=noninteractive sudo apt-get install -y apache2

# 設定 Apache
RUN echo "ServerName ubuntu.com.tw" >> /etc/apache2/apache2.conf \
&& sudo ufw allow in "Apache Full" \
&& chmod -R 777 /var/www/html/ \
&& chown -R www-data:www-data /var/www/html/ \
&& a2enmod rewrite \
&& /etc/init.d/apache2 restart

# 移除 加 新增檔案
RUN rm -r /var/www/html/index.html \
&& echo "<?php phpinfo(); ?>" > /var/www/html/index.php

# 安裝 5.6 版本的套件
RUN DEBIAN_FRONTEND=noninteractive apt-get update -y
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y php5.6 libapache2-mod-php php5.6-mysql \
php5.6-common php5.6-cli php5.6-gd php5.6-mysql php5.6-mysqli \
php5.6-curl php5.6-intl php5.6-mbstring php5.6-bcmath php5.6-imap \
php5.6-xml php5.6-zip php5.6-mcrypt php-xdebug

# 定制為 5.6 版本
RUN sudo update-alternatives --set php /usr/bin/php5.6

# 安裝 phpMyAdmin
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y phpmyadmin \
&& cp /etc/phpmyadmin/apache.conf /etc/apache2/conf-available/phpmyadmin.conf \
&& sudo a2enconf phpmyadmin

# 清除
RUN apt-get update && apt-get upgrade -y
RUN apt-get -y clean && apt-get -y autoremove
RUN rm -rf /var/lib/apt/lists/*

RUN printf "#!/bin/sh\n/usr/sbin/apachectl --dforeground\n/etc/init.d/mysql start\ntail -F /var/log/mysql/error.log" > /start.sh
RUN sudo chmod -R 777 /start.sh
CMD ["/start.sh", "-D", "FOREGROUND"]

WORKDIR /var/www/html
EXPOSE 80