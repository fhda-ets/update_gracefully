# update_gracefully
Apply yum updates and notify the sysadmin if restart is required

## About

This script will automatically create the log and config files if they do not exist.  This script uses ONLY core Perl modules - no additional modules need to be 
installed.

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

By default, the system will attempt to email the user running the script.  If you wish to send emails to a different address, you can do so by overriding the 
sysadmin-email variable as specified below:

```
sysadmin-email=user@host.com
```


