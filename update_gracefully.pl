#!/usr/bin/perl
use warnings;
use strict;
use Getopt::Long;
use FindBin;
use lib $FindBin::Bin;
my $help=0; my $cron=0; my $restart=0; my $email=''; my $smtp='';
GetOptions (	"h|help" => \$help,
		"c|cron" => \$cron,
		"s|smtp=s" => \$smtp,
		"r|restart" => \$restart,
		"e|email=s" => \$email,
) or die "Error in command line arguments.\n";
if ($help) { show_help(); }

# THIS SCRIPT WILL ATTEMPT TO APPLY ANY NEW PATCHES WITH yum -u update AND THEN
# CHECK TO SEE IF THE SYSTEM REQUIRES AN UPDATE.  IF AN UPDATE IS REQUIRED, THE
# SYSTEM SHOULD SEND AN EMAIL TO THE ADMINISTRATOR.
# IT'S PROBABLY BEST NOT TO MODIFY THIS FILE WITHOUT FORKING THE REPO.

# WHERE SHOULD WE LOG DATA?
my $logfile = '/var/log/update_gracefully.log';

# WHEN DID WE START?
chomp (my $current_time = `/usr/bin/date +"%Y-%m-%d %H:%M"`);
print_log("Beginning script at $current_time.\n");

# WHO SHOULD GET THE NOTIFICATION EMAILS?
chomp (my $sysadmin_email = `/usr/bin/whoami`);
if ($email ne '') { $sysadmin_email = $email; }

(my $auto_restart, my $override_email, my $override_smtp) = check_config();
if ($restart) { $auto_restart = 'yes'; }
if ($override_email ne '') { $sysadmin_email = $override_email; }
if ($override_smtp ne '') { $smtp = $override_smtp; }

# GET SOME INFORMATION ABOUT THE STATE OF THIS SYSTEM
chomp (my $server_name = `/usr/bin/hostname`);
my $all_ips = `cat /etc/sysconfig/network-scripts/ifcfg-* | grep -i ipaddr | uniq`;

# STEP 1a: LET'S MAKE SURE THE LOG FILE EXISTS
unless (-e $logfile) {
	print_log(" - Log file not found at [ $logfile ].\n - Attempting to create log file...");
	my $result = `touch $logfile`;
	if ($result ne '') {
		die "\n\nLog file does not exist and cannot be created: [$result].\n";
	}
	print_log("   Success.\n");
}

# STEP 1b: LET'S MAKE SURE THE needs-restarting COMMAND IS AVAILABLE FROM yum-utils
unless (-e '/usr/bin/needs-restarting') {
	print_log(" - yum-utils does not appear to be installed.  Installing...  ");
	my $get_yum_utils_cmd = '/usr/bin/yum -y install yum-utils';
	my $result = `$get_yum_utils_cmd`;
	if ($result =~ /Complete/i) { print_log("Success.\n"); }
	else {
		print_log("Could not install yum-utils: [$result].\n");
		 die "Ugh.";
	}
}

# STEP 2: USE yum TO INSTALL ANY NEW UPDATES
print_log(" - Attempting to installing new updates with [ yum -y update ]. (This may take a while!).\n");
my $yum_update_cmd = '/usr/bin/yum -y update';
my $result = `$yum_update_cmd`;
if (($result =~ /failed/i) or ($result =~ /error/i)) {
	print_log("Possible error while applying updates.  Output of [yum -y update] attached...\n");
	print_log("$result\n");
}
elsif ($result =~ /No packages marked for update/i) {
	print_log(" - No updates to apply.  Exiting gracefully.\n");
	unless ($restart) { exit; }
	print_log(" - Script called with --restart, overridding exit and will check for update required anyway...\n");
}

# STEP 3: CHECK TO SEE IF RESTART IS REQUIRED
my $restart_required_cmd = '/usr/bin/needs-restarting -r; echo $?';
$result = `$restart_required_cmd`;
if ($result =~ /Reboot is probably not necessary/i) {
	print_log(" - Reboot does not appear to be required at this time.\n");
}
elsif ($result =~ /Reboot is required to ensure that your system benefits from these updates/i) {

	if ($auto_restart =~ /yes/i) {
		print_log(" - We're living on the edge and automatically restarting.\n");
		my $sub = "Server $server_name AUTOMATICALLY REBOOTED after applying patches!";
		my $body = $sub . "\n\nIt's probabaly a good idea to check that it came up OK!\n";
		$body .= "List of IPs for this server:\n$all_ips";
		send_email($sub, $body);
		# WE SHOULD WAIT A FEW SECONDS FOR THE EMAIL TO BE SENT BEFORE WE REBOOT
		sleep 30;
		my $result = `/usr/sbin/shutdown -r now`;
	}
	print_log(" - Reboot required.  Notifying sysadmin.\n");
	my $sub = "Server $server_name requires a reboot after applying patches!";
	my $body = $sub . "\n\nPlease schedule a reboot with the end-users at an appropriate time.";
	$body .= "List of IPs for this server:\n$all_ips";
	send_email($sub, $body);
}
else {
	print_log("It appears updates were applied, but needs-restarting did not return an anticipated result...?\n");
	my $sub = "Server $server_name in unknown state  after applying patches!";
	my $body = $sub . "\n\nAfter applying patches to $server_name, needs-restarting did not return a result";
	$body .= " I know how to handle.  Please login and check the logs to see what needs to be done!\n";
	$body .= "List of IPs for this server:\n$all_ips";
	send_email($sub, $body);
}

sub send_email {
	my $subject = shift;
	my $body = shift;
	my $attempts = 5;
	my $smtp_string = '';
	if ($smtp ne '') { $smtp_string = "-S smtp=smtp://$smtp"; }
	my $send_email_string = "echo \"$body\" | mailx $smtp_string -s \"$subject\" \"$sysadmin_email\" 2>&1";
	my $email_result = '';
	my $num_tries;
	for ($num_tries = 0; $num_tries <= $attempts; $num_tries++) {
		$email_result = `$send_email_string`;
		if ($email_result =~ /error/) {
			print_log("Error sending email on pass $num_tries.\n");
			sleep 10;
			next;
		}
		else { last; }
	}
	if ($num_tries >= $attempts) {
		print_log("Could not create send email:\n[ $send_email_string ]\ngenerated error:\n[ $! ]\n[ $email_result ]");
		die "Ugh.";
		}
}

sub print_log {
	my $this_data = shift;
	if (-e $logfile) {
		open(my $FH, '>>', $logfile);
		print $FH $this_data;
		close $FH;
	}
	unless ($cron) { print $this_data; }
}

sub show_help {
	print <<"END_HELP";
Showing usage information.

$0 [-h|--help] [-c|--cron] [-r|--restart] [-e|--email user\@host.com] [-s|--smtp host.domain.com]
	-h | --help	Display this help message and exit.
	-c | --cron	Suppress all non-error messages.
	-r | --restart	Override the default / config file and restart if needed.
	-e | --email	Override the default / config file and email specified address.
	-s | --smtp	Override the default / config file and email via specified smtp server.

This code will run the yum updater and install any new packages.  In the event a package requires
a reboot, the code will send an email to the system administrator with the appropriate information.

Specifiying --cron will cause the system to suppress all non-error output which is typically output
on STDOUT.  This is useful when you wish to run the script from cron without redirecting cron out
to /dev/null.  It is expected the script will be called from cron via an entry such as:

# CHECK FOR UPDATES AT THREE AM EVERY DAY:
0 3 * * * /opt/update_gracefully/update_gracefully.pl

You may optionally specifiy that the default actions be overridden.  Please see the github README.md
for more information.

END_HELP
	exit;


}

sub check_config {
	my $auto_restart = 0;
	my $override_email = '';
	my $override_smtp = '';
	my $config_file = $FindBin::Bin . '/config.txt';
	print_log(" - Parsing $config_file...");
	if (-e $config_file) {
		open (my $FH, '<', $config_file);
		while (my $row = <$FH>) {
			if ($row =~ /^autorestart\s*=*\s*(\S+)$/i) {
				$auto_restart = $1;
				print_log("  auto-restart: $auto_restart.");
			}
			elsif ($row =~ /^sysadmin-email\s*=*\s*(\S+)$/i) {
				$override_email = $1;
				if ($override_email =~ /=/) { $override_email = ''; }
				else {
					print_log("  email override: $override_email.");
				}
			}
			elsif ($row =~ /^smtp\s*=*\s*(\S+)$/i) {
				$override_smtp = $1;
				if ($override_smtp =~ /=/) { $override_smtp = ''; }
				else {
					print_log("  smtp override: $override_smtp.");
				}
			}
		}
		print_log("\n");
		return ($auto_restart, $override_email, $override_smtp);
	}
	else {
		# IF THE CONFIG FILE DOESN'T EXIST YET, LET'S CREATE IT
		my $result = `echo "autorestart=no\nsysadmin-email=">$config_file`;
		print_log("File does not exist.  Creating config file at $config_file.\n");
	}
	return ('no', $sysadmin_email, '');
}
