#!/bin/bash

#installing php 7.3+
yum -y install yum-utils php php-common php-mysql php-gd php-xml php-mbstring php-mcrypt
yum -y install http://rpms.remirepo.net/enterprise/remi-release-7.rpm
yum-config-manager --enable remi-php73

#install Apache webserver
yum -y install httpd
systemctl start httpd
systemctl enable httpd

#install MariaDB
yum -y install mariadb mariadb-server wget expect
systemctl start mariadb
systemctl enable mariadb

#DB parameters
MYSQL_ROOT_PASS="ololoandAbottleOfRum"
DB_USER="demouser"
DB_PASS="MyStrongPass"

#preforming mysql_secure_installation
expect -f - <<-EOF
set timeout 10
spawn mysql_secure_installation
expect {
    {*password for root} {send "$MYSQL_ROOT_PASS\r";exp_continue}
    {Set root password? \[Y/n\] } {send "y\r";exp_continue}
    {New password:} {send "$MYSQL_ROOT_PASS\r";exp_continue}
    {Re-enter new password:} {send "$MYSQL_ROOT_PASS\r";exp_continue}
    {Remove anonymous users? } {send "y\r";exp_continue}
    {Disallow root login remotely? } {send "y\r";exp_continue}
    {Remove test database and access to it?} {send "y\r";exp_continue}
    {Reload privilege tables now?} {send "y\r";exp_continue}
}
expect eof
EOF

#config database
mysql -u root --password=$MYSQL_ROOT_PASS <<MYSQL
CREATE DATABASE wordpressdb;
CREATE USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';
GRANT ALL PRIVILEGES ON wordpressdb.* TO '$DB_USER'@'localhost';
FLUSH PRIVILEGES;
EXIT;
MYSQL
systemctl restart mariadb

#downloading wordpress `n installing
wget -O /tmp/latest.tar.gz http://wordpress.org/latest.tar.gz
unzip -q /tmp/latest.tar.gz -d /var/www/html
chown -R apache:apache /var/www/html/wordpress/ && chmod -R 0755 /var/www/html/wordpress
mkdir -p /var/www/html/wordpress/wp-content/uploads && chown :apache /var/www/html/wordpress/wp-content/uploads
mv /var/www/html/wordpress/wp-config-sample.php /var/www/html/wordpress/wp-config.php

#setup wp basic config
sed -i 's/database_name_here/wordpress/' /var/www/html/wordpress/wp-config.php
sed -i 's/username_here/dbuser/' /var/www/html/wordpress/wp-config.php
sed -i 's/password_here/0000/' /var/www/html/wordpress/wp-config.php

#adding firewall rule
firewall-cmd --zone=public --add-service=http --permanent
firewall-cmd --reload

#final message - hello world
ipaddr=$(hostname -I | awk '{print $1}')
echo "Link to finish wordpress installation: http://$ipaddr/wordpress/wp-admin/install.php"
