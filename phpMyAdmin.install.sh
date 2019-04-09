# =========================================== #
#                                             #
#            phpMyAdmin.install               #
#                                             #
# =========================================== #


# Update Resolve Servers
echo "nameserver 8.8.8.8" > /etc/resolv.conf
echo "nameserver 8.8.4.4" >> /etc/resolv.conf
# File Check
if [ -f /etc/network/interfaces ]; then
sed -i 's/dns-nameservers \(.*\)/\Edns-nameservers 8.8.8.8 8.8.4.4/g' /etc/network/interfaces
fi

# Install yum
sudo apt-get install yum

# Update
apt-get -y update
yum -y update

# Install: lsb-release
apt-get -y instredhat-lsb curl ntpdate
/usr/sbin/ntpdate -u pool.ntp.orgall lsb-release curl sudo ntpdate
yum -y install 

# Get Public Interface
IFACE="$(/sbin/route | grep '^default' | grep -o '[^ ]*$')"

# Get Public IP
IP="$(curl -4 icanhazip.com)"


export MySQLRoot=`cat /dev/urandom | tr -dc A-Za-z0-9 | dd bs=25 count=1 2>/dev/null`
export AdminPassword=`cat /dev/urandom | tr -dc A-Za-z0-9 | dd bs=25 count=1 2>/dev/null`

DISTRO="$(lsb_release -si)"
VERSION="$(lsb_release -sr | cut -d. -f1)"
OS="$DISTRO$VERSION"

# Begin Ubuntu
if [ "${DISTRO}" = "Ubuntu" ] ; then
apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 8507EFA5
echo "deb http://repo.percona.com/apt "$(lsb_release -sc)" main" | sudo tee /etc/apt/sources.list.d/percona.list
echo "deb-src http://repo.percona.com/apt "$(lsb_release -sc)" main" | sudo tee -a /etc/apt/sources.list.d/percona.list
apt-get -y purge `dpkg -l | grep php| awk '{print $2}' |tr "\n" " "`
apt-get install -y language-pack-en-base
export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8
apt-get install -y software-properties-common
add-apt-repository -y ppa:ondrej/php
apt-get update
apt-get -y upgrade
export DEBIAN_FRONTEND="noninteractive"
apt-get -y install apache2 php5.6 php5.6-mysqlnd sqlite php5.6-gd php5.6-mbstring php5.6-xml php5.6-curl php5.6-sqlite wget nano zip unzip percona-server-server-5.6 git dos2unix
fi

# Set MySQL Password
/sbin/service mysql start
service mysql start
mysql -e "SET PASSWORD FOR 'root'@'localhost' = PASSWORD('${MySQLRoot}');"


WebRoot="/var/www/html"

# Automated phpMyAdmin Installer
cd ${WebRoot}/
git clone --depth=1 --branch=STABLE git://github.com/phpmyadmin/phpmyadmin.git phpMyAdmin
mv ${WebRoot}/phpMyAdmin/config.sample.inc.php ${WebRoot}/phpMyAdmin/config.inc.php
sed -i "s/\$cfg\[.blowfish_secret.\]\s*=.*/\$cfg['blowfish_secret'] = '${BlowFish}';/" ${WebRoot}/phpMyAdmin/config.inc.php
cd ${WebRoot}/phpMyAdmin/
wget https://getcomposer.org/composer.phar -O composer.phar
php composer.phar update --no-dev

# php.ini Auto-Detector
PHP="$(php -r "echo php_ini_loaded_file();")"
rm -fv /etc/php.ini
ln -s ${PHP} /etc/php.ini

# Modify php.ini Settings
sed -i 's/upload_max_filesize = \(.*\)/\Eupload_max_filesize = 100M/g' /etc/php.ini
sed -i 's/post_max_size = \(.*\)/\Epost_max_size = 100M/g' /etc/php.ini
sed -i 's/max_execution_time = \(.*\)/\Emax_execution_time = 300/g' /etc/php.ini
sed -i 's/max_input_time = \(.*\)/\Emax_input_time = 600/g' /etc/php.ini

# Restart Services
service apache2 stop
service apache2 start
/sbin/service httpd stop
/sbin/service httpd start

# Output Vars
cd /root/
cat > logins.conf << eof
# Stored Passwords
MySQL Root Password: ${MySQLRoot}

# phpMyAdmin Link
http://${IP}/phpMyAdmin/index.php
Username: root
Password: ${MySQLRoot}
eof

cat /root/logins.conf

# Fix Remote MySQL Issues for server
mysql -e "SET PASSWORD FOR 'root'@'127.0.0.1' = PASSWORD('${MySQLRoot}');"
mysql -Dmysql -e "DELETE FROM user WHERE Password='';"
mysql -Dmysql -e "DROP USER ''@'%';"
mysql -Dmysql -e "FLUSH PRIVILEGES;"