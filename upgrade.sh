########################################################
# Simple Update script to pull latest master from github
# -Abel
########################################################
#!/bin/sh
nmsversion="21.12.1"
zip_file="$nmsversion.zip"
zip_files_url=https://github.com/librenms/librenms/archive/$zip_file
wget_err="/tmp/wget_err.log"
wget_opt="-nH --cut-dirs=2 -nv"
echo Download Latest LibreNMS
wget $wget_opt -P /tmp $zip_files_url 2>$wget_err 1>/dev/null
if [ $? -ne 0 ]; then
    errmsg=`cat $wget_err`
    echo Abort: $errmsg
else
    echo Preparing to Upgrade
    chown librenms:librenms /tmp/$zip_file
    unzip /tmp/$zip_file -d /tmp/
    service httpd stop
    service mysqld stop
    rpm -qa | grep -qw php-mbstring || yum install -y php-mbstring
    rpm -qa | grep -qw python3-devel || yum install -y python3-devel
    if [ -d /opt/librenms-old ]; then
        echo "Old NMS directory found. Removing .."
        rm -rf /opt/librenms-old
    fi
    mv /opt/librenms /opt/librenms-old
    mv /tmp/librenms-$nmsversion /opt/librenms/
    /bin/cp -Ruf /opt/librenms-old/rrd /opt/librenms/
    cp /opt/librenms-old/config.php /opt/librenms/
    /bin/cp -Ruf /opt/librenms-old/logs /opt/librenms/
    if [ -d /opt/librenms-old/.composer ]; then
        echo ".composer directory found, migrating to new location."
        /bin/cp -Ruf /opt/librenms-old/.composer /opt/librenms/
    fi
    if [ -f /opt/librenms-old/composer.phar ]; then
        echo "composer.phar found, migrating to new location."
        /bin/cp -Ruf /opt/librenms-old/composer.phar /opt/librenms/
    fi
    /bin/cp -Ruf /opt/librenms-old/vendor /opt/librenms/
    /bin/cp -Ruf /opt/librenms-old/html/images/custom /opt/librenms/html/images/custom
    rm -f /tmp/$zip_file $wget_err
    chmod 775 /opt/librenms/rrd
    chmod ug+rw /opt/librenms/rrd
    chmod ug+rw /opt/librenms/logs
    cp /opt/librenms/librenms.nonroot.cron /etc/cron.d/librenms
    cp /opt/librenms/misc/librenms.logrotate /etc/logrotate.d/librenms
    if [ -f /opt/librenms/misc/lnms-completion.bash ]; then
        echo "creating lnms links."
        ln -s /opt/librenms/lnms /usr/local/bin/lnms
        cp /opt/librenms/misc/lnms-completion.bash /etc/bash_completion.d/
    fi
    service httpd start
    service mysqld start
    chown -R librenms:librenms /opt/librenms
    su librenms -c 'COMPOSER_HOME="/opt/librenms" php /opt/librenms/scripts/composer_wrapper.php install --no-dev'
    su librenms -c '/opt/librenms/daily.sh no-code-update'
    setfacl -d -m g::rwx /opt/librenms/rrd /opt/librenms/logs /opt/librenms/bootstrap/cache/ /opt/librenms/storage/
    chmod -R ug=rwX /opt/librenms/rrd /opt/librenms/logs /opt/librenms/bootstrap/cache/ /opt/librenms/storage/
    echo "Upgrade Complete. Examine validation for additional changes"
    su librenms -c '/opt/librenms/validate.php'
fi
