#!/bin/bash

# Ensure the script is run as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root."
    exit
fi

# Update package list
apt-get update

# Install Apache 2.4
echo "Installing Apache 2.4..."
apt-get install apache2 -y

# Ensure mod_rewrite is enabled
echo "Enabling mod_rewrite..."
a2enmod rewrite

# Prompt for the site name
read -p "Enter the site name (e.g., example.com): " site

# Check if the user entered a site name
if [ -z "$site" ]; then
    echo "Error: Site name cannot be empty."
    exit 1
fi

# Create root folders for the vhost
echo "Creating directories for $site..."
mkdir -p /var/www/$site/log
mkdir -p /var/www/$site/web

# Set ownership and permissions
echo "Setting ownership and permissions..."
chown -R www-data:webadmins /var/www/$site
chmod -R 775 /var/www/$site

# Create the virtual host configuration file
echo "Creating virtual host configuration..."
vhost_conf="/etc/apache2/sites-available/$site.conf"
echo "<VirtualHost *:80>
    ServerAdmin webmaster@$site
    ServerName $site
    DocumentRoot /var/www/$site/web
    ErrorLog /var/www/$site/log/error.log
    CustomLog /var/www/$site/log/access.log combined

    <Directory /var/www/$site/web>
        AllowOverride All
        Require all granted
    </Directory>
</VirtualHost>" > $vhost_conf

# Enable the site
echo "Enabling the site $site..."
a2ensite $site.conf

# Restart Apache to apply changes
echo "Restarting Apache..."
systemctl restart apache2

echo "$site has been configured and Apache has been restarted."

# Install PHP and required modules
echo "Installing PHP and required modules..."

# Check Debian version
debian_version=$(lsb_release -sc)
if [[ "$debian_version" == "buster" || "$debian_version" == "bullseye" ]]; then
    # Add PHP repository for Debian 10 or 11
    echo "Adding PHP repository..."
    apt-get install apt-transport-https lsb-release ca-certificates wget -y
    wget -O /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg
    sh -c 'echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/php.list'
    apt-get update
fi

# Install PHP and modules
apt-get install php libapache2-mod-php php-mysql php-curl php-mbstring php-imagick php-gd -y

# Get the PHP version
php_version=$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;')

if [ -z "$php_version" ]; then
    echo "Error: PHP installation failed."
    exit 1
else
    echo "PHP $php_version installed successfully."
fi

# Enable PHP extensions
echo "Enabling PHP extensions..."
phpenmod curl mbstring imagick gd

# Restart Apache to apply the PHP configuration changes
echo "Restarting Apache to apply PHP configuration..."
systemctl restart apache2

echo "PHP and extensions have been configured successfully."
