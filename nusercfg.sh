#!/bin/bash
#script that add new user in system and configurate FTP service for him(including SSH/SFTP)
#uses single option: new user name(required)
#Configuring logging
set -e
LOG_F="/tmp/sftp-server-setup_"`date "+%F-%T"`".log"
exec &> >(tee "${LOG_F}")
echo "Logging setup to ${LOG_F}"
#if user exist
if grep -w $1 /etc/passwd
then
#Post message about it and skip adding user
echo -e "User\033[33m $1\033[0m already exist"
else
#Create NEW user without password request at sudo command
sudo adduser $1
sudo passwd $1
sudo usermod -aG wheel $1
sudo echo '$1 ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/$1
sudo chmod 0440 /etc/sudoers.d/$1
fi
#Updating system and installing vsftpd server
sudo yum update -y
sudo yum install vsftpd -y
#Running vsftpd service
sudo systemctl start vsftpd
sudo systemctl enable vsftpd
#Congiguring firewall to allow FTP traffic on Port 21
sudo firewall-cmd --zone=public --permanent --add-port=21/tcp
sudo firewall-cmd --zone=public --permanent --add-service=ftp
sudo firewall-cmd --reload
#
#Backup default config of vsfpd service
ls /etc/vsftpd/ | grep 'vsftpd.conf.default$' || sudo cp /etc/vsftpd/vsftpd.conf /etc/vsftpd/vsftpd.conf.default && sudo cp /etc/vsftpd/vsftpd.conf "/etc/vsftpd/vsftpd.conf.default."`date "+%F-%T"`
#
#Function for changing config
change_config () {
grep -q "^$1" /etc/vsftpd/vsftpd.conf && sudo sed -i 's/^$1.*/$1=$2/' /etc/vsftpd/vsftpd.conf || echo "$1=$2" | sudo tee -a /etc/vsftpd/vsftpd.conf
}
#Configuring vsftpd server
change_config anonymous_enable NO
change_config local_enable YES
change_config write_enable YES
change_config chroot_local_user YES
change_config allow_writeable_chroot YES
change_config userlist_enable YES
change_config userlist_file /etc/vsftpd/user_list
change_config userlist_deny NO
change_config chroot_list_enable YES
change_config chroot_list_file /etc/vsftpd/chroot_list
change_config pasv_enable YES
#change_config pasv_max_port 10001
#change_config pasv_min_port 10000
#
#Configuring sftp user
cat /etc/vsftpd/user_list | grep $1 && echo $1 | tee -a /etc/vsftpd/user_list
cat /etc/vsftpd/chroot_list | grep $1 && echo $1 | tee -a /etc/vsftpd/chroot_list
#Restarting vsftpd service
sudo systemctl restart vsftpd
#Restarting sft service
sudo systemctl restart sshd
echo -e "Configuring user\033[33m $1\033[0m permissions for SFTP server was \033[32mDone !\033[0m"
