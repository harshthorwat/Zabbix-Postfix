# zabbix-postfix-template
# Requirements
* [pflogsum](http://jimsun.linxnet.com/postfix_contrib.html)
* [pygtail](https://pypi.org/project/pygtail/)

# Installation
    # for Ubuntu / Debian
    apt-get install pflogsumm

    # for CentOS
    yum install postfix-perl-scripts

    cp pygtail.py /usr/sbin/
    chmod +x /usr/sbin/pygtail.py

    # ! check MAILLOG path in zabbix-postfix-stats.sh
    cp zabbix-postfix-stats.sh /usr/bin/
    chmod +x /usr/bin/zabbix-postfix-stats.sh

    cp userparameter_postfix.conf /etc/zabbix/zabbix_agentd.d/

    # run visudo as root
    Defaults:zabbix !requiretty
    zabbix ALL=(ALL) NOPASSWD: /usr/bin/zabbix-postfix-stats.sh

    systemctl restart zabbix-agent

Finally import template_app_zabbix.xml and attach it to your host


Add this lines to the Crontab.

sudo crontab -e

*/1 * * * * /root/mnt_log >> /root/mnt_log.log

*/5 * * * * /usr/bin/maillog.sh &> /dev/null

0 0 * * * /usr/bin/rm /tmp/postfix_statsfile.dat /tmp/zabbix-postfix-offset.dat

