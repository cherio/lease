#!/usr/bin/perl
# SPDX-License-Identifier: 0BSD

use strict;
use warnings;
use Cwd();
use Time::HiRes();
use Getopt::Long qw(:config no_auto_abbrev no_ignore_case bundling);

Getopt::Long::GetOptions (
	'resource|r=s' => \(my $resource_id), # ID of the resource everyone competes for
	'pid|p=i' => \(my $owner_pid), # process that wants to lease/own the resource
	'dir|d=s' => \(my $queue_dir), # queue & semaphore lock file DIR
	'concurrency|c=i' => \(my $concurrency = 1), # max number of parallel resource owners
	'exclusivity|x=s' => \(my $exclusivity = 'X'), # exclusivity group code/identifier
	'wait|w=f' => \(my $total_wait_sec), # in seconds total wait time for the resource to become available
	'interval|i=f' => \(my $wakeup_interval_sec), # wake up this often to re-check the queue
	'kill|k=s' => \(my $kill_age_spec), # if another owner process is "stuck", TERM it after this many SECONDS
	'expire|e=f' => \(my $expire_age_sec), # resource will be considered automatically unlocked after this period
	'release|R' => \(my $release), # request to release the lock on the resource
	'verbose|v+' => \(my $verbose = 0), # verbosity level, can be specified multiple times
	'test=s' => (\my $test_spec),
	'help|h' => sub { help(); exit(0); } # need help?
); # or die("Invalid command line options.\nRun with '--help'\n");

my ($script_dir, $script_name, $script_base_name) = ((Cwd::abs_path($0) =~ /^([^^]*?)\/(([^\/]+?)\.[^\.\/]++)$/) ? ($1, $2, $3) : die("Don't understand"));
my $lease_exe = Cwd::abs_path("$script_dir/../lease");

run_tests($test_spec // die("No test specified with --test=<value>"));
exit(0);

sub run_tests { # Basic self test
	# Example: <semaphore> --test=16x2+3 -r test -c 2 -i 3 -w 16 -k 4 -v -v --release 2>&1 | tee /path/sema.log
	my $test_spec = shift; # -t <value>, where value is '<process_count>x<process_duration>+<random variation>'
	my ($parallel_process_count, $process_duration, $process_duration_rand) = split(/\D+/, $test_spec); ## ($test_spec =~ /(\d+)/g);
	print("Spec: $test_spec\n");

	my @cmd = ($lease_exe); # Duplicate arguments from the caller
	push(@cmd, "--resource=$resource_id");
	push(@cmd, "--dir=$queue_dir") if $queue_dir;
	push(@cmd, "--interval=$wakeup_interval_sec") if $wakeup_interval_sec;
	push(@cmd, "--kill=$kill_age_spec") if $kill_age_spec;
	push(@cmd, "--wait=$total_wait_sec") if $total_wait_sec;
	# push(@cmd, "--concurrency=$concurrency") if $concurrency;
	push(@cmd, ("-v") x $verbose ) if $verbose;

	my @release_cmd = ($lease_exe);
	push(@release_cmd, "--resource=$resource_id", '--release');
	push(@release_cmd, "--dir=$queue_dir") if $queue_dir;
	push(@release_cmd, ("-v") x $verbose ) if $verbose;

	my @child_pids = (); # Collect child process IDs here
	for (my $child_index = 0; $child_index < $parallel_process_count; $child_index++) { # Run child processes
		#Time::HiRes::sleep(0.05);
		my $child_pid = fork();
		if ($child_pid == 0) { # Child
			my $delayed_start = rand(2);
			print("Delaying start by $delayed_start, $$\n");
			Time::HiRes::sleep($delayed_start); # delayed start

			my $started_sec = Time::HiRes::time();
			my $random_exclusive = int(rand(2)) ? 'X' : 'S';
			my $random_concurrency = defined($concurrency) ? $concurrency : int(rand(3)) + 2;
			my @child_cmd = (@cmd, ("-x", $random_exclusive, '-c', $random_concurrency));
			push(@child_cmd, "--pid=$$");
			print("Requesting lock, x=$random_exclusive, $$\n");
			# my $child_cmd_text = join(' ', map { cmd_arg($_) } @child_cmd);
			system(@child_cmd);
			my $sleep_duration = $process_duration + ($process_duration_rand ? rand($process_duration_rand) : 0);
			print("Working for $sleep_duration sec, $$\n");
			Time::HiRes::sleep($sleep_duration); # Performing some task
			system(@release_cmd, "--pid=".$$) if ($release);
			print("Done PID: ".$$.", $random_exclusive, sec: ".(Time::HiRes::time() - $started_sec)."\n");
			exit(0); # The child is done
		}
		push(@child_pids, $child_pid); # Save PID
	}

	while (@child_pids) { waitpid(shift(@child_pids), 0) } # Wait for every child to finish
}
