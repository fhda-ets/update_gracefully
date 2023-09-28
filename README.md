# update_gracefully

Use the yum package manager to apply any available updates to the system and notify the sysadmin if restart is required.  Optionally - automatically restart the 
system and/or notify other users.

## About

This script will automatically create the log and config files if they do not exist.  This script originally used ONLY core Perl modules - no additional modules 
needed to be installed. However, as of CentOS 9 Stream, you must manually ensure that perl-Findbin is available (e.g., 'dnf install perl-FindBin'). If you are 
running CentOS9, be aware that mailx is no longer available, so you'll need to ensure s-nail is installed (e.g., 'dnf install s-nail'). As the script requires root 
access to perform system updates, it is expected that you will run this file out of the root cron.  We recommed something similar to the following:

```
# CHECK FOR UPDATES AT THREE AM EVERY DAY:
0 3 * * * /opt/update_gracefully/update_gracefully.pl --cron
```

## Config Options

On first run, this script will create a config file called config.txt in the directory where the script resides.  The .gitignore files prevents this file from 
leaking out beyond the server.  If you wish to override any of the default functions below, set the variables as specified:

### Automatically restart if a restart is required.

By default, the system WILL NOT automatically restart the server.  If you wish to override this functionallity, you can do so either by calling the script with 
--restart, or by editing the config.txt file and changing the autorestart variable as specified below:

```
autorestart=yes
```

### Overriding the email address to notify of changes

By default, the system will attempt to email the user running the script.  If you wish to send emails to a 
different address, you can do so by calling the system with --email, or by overriding the sysadmin-email 
variable as specified below:

```
sysadmin-email=user@host.com
```

Note that you can generally achieve the same functionality by dropping a .forward entry containing the email address into the home folder of the root user 
(typically /root).

### Overriding the mail exchange smtp server 

By default, the system will attempt to send email via the local host.  If you wish to specify a different 
smtp server, you can do so by calling the system with --smtp, or by overriding the smtp variable as 
specified below:
```
smtp=host.domain.com
```

Note that this is most commonly done to bypass the "[EXT]: " email subject prefix when emails are received from 
addresses/servers not associated with your organization.

### Specify CentOS/RHEL 6

By default, the system will assume CentOS/RHEL 7.  You can override this via the --version option, or by modifying the config.txt file:
```
rh6=yes
```

