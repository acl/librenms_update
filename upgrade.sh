########################################################
# Simple Update script to pull latest master from github
# -Abel
########################################################
#!/bin/sh

 nmsversion="1.50.1"
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

 if [ -d /opt/librenms-old ]; then
     echo "Old NMS directory found. Removing .."
     rm -rf /opt/librenms-old
 fi

 mv /opt/librenms /opt/librenms-old
 mv /tmp/librenms-$nmsversion /opt/librenms/
 /bin/cp -Ruf /opt/librenms-old/rrd /opt/librenms/
 cp /opt/librenms-old/config.php /opt/librenms/
 /bin/cp -Ruf /opt/librenms-old/logs /opt/librenms/
 /bin/cp -Ruf /opt/librenms-old/.composer /opt/librenms/
 /bin/cp -Ruf /opt/librenms-old/composer.phar /opt/librenms/
 /bin/cp -Ruf /opt/librenms-old/vendor /opt/librenms/
 /bin/cp -Ruf /opt/librenms-old/html/images/custom /opt/librenms/html/images/custom
 rm -f /tmp/$zip_file $wget_err
 chmod 775 /opt/librenms/rrd
 chmod ug+rw /opt/librenms/rrd
 chmod ug+rw /opt/librenms/logs
 cp /opt/librenms/librenms.nonroot.cron /etc/cron.d/librenms
 cp /opt/librenms/misc/librenms.logrotate /etc/logrotate.d/librenms

 service httpd start
 service mysqld start
 /opt/librenms/scripts/composer_wrapper.php install --no-dev
 chown -R librenms:librenms /opt/librenms
 /opt/librenms/daily.sh no-code-update
 setfacl -d -m g::rwx /opt/librenms/rrd /opt/librenms/logs /opt/librenms/bootstrap/cache/ /opt/librenms/storage/
 chmod -R ug=rwX /opt/librenms/rrd /opt/librenms/logs /opt/librenms/bootstrap/cache/ /opt/librenms/storage/

 echo Upgrade Complete
 fi