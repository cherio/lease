#!/usr/bin/perl
use strict;
use warnings;

use Cwd();

my ($script_dir, $script_name, $script_base_name) = ((Cwd::abs_path($0) =~ /^([^^]*?)\/(([^\/]+?)\.[^\.\/]++)$/) ? ($1, $2, $3) : die("Don't understand"));
my $lease_exe = Cwd::abs_path("$script_dir/../lease");

do $lease_exe || die("No lease");

eval <<'CODE';
sub run_tests { # Basic self test
	# Example: <semaphore> --test=16x2+3 -r test -c 2 -i 3 -w 16 -k 4 -v -v --release 2>&1 | tee /path/sema.log
	my $test_spec = shift; # -t <value>, where value is '<process_count>x<process_duration>+<random variation>'
	my ($parallel_process_count, $process_duration, $process_duration_rand) = split(/\D+/, $test_spec); ## ($test_spec =~ /(\d+)/g);

	my @cmd = ($lease_exe); # Duplicate arguments from the caller
	push(@cmd, "--resource=$resource_id");
	push(@cmd, "--dir=$queue_dir") if $queue_dir;
	push(@cmd, "--interval=$wakeup_interval_sec") if $wakeup_interval_sec;
	push(@cmd, "--kill=$kill_age_spec") if $kill_age_spec;
	push(@cmd, "--wait=$total_wait_sec") if $total_wait_sec;
	# push(@cmd, "--concurrency=$concurrency") if $concurrency;
	push(@cmd, ("-v") x $verbose ) if $verbose;

	my @release_cmd = ($0);
	push(@release_cmd, "--resource=$resource_id", '--release');
	push(@release_cmd, "--dir=$queue_dir") if $queue_dir;
	push(@release_cmd, ("-v") x $verbose ) if $verbose;

	my @child_pids = (); # Collect child process IDs here
	for (my $child_index = 0; $child_index < $parallel_process_count; $child_index++) { # Run child processes
		#Time::HiRes::sleep(0.05);
		my $child_pid = fork();
		if ($child_pid) { # Parent - caller
			push(@child_pids, $child_pid); # Save PID
		} else { # Child
			my $delayed_start = rand(2);
			prnt("Delaying start by $delayed_start, $$\n");
			Time::HiRes::sleep($delayed_start); # delayed start

			my $started_sec = Time::HiRes::time();
			my $random_exclusive = int(rand(2)) ? 'X' : 'S';
			my $random_concurrency = defined($concurrency) ? $concurrency : int(rand(3)) + 2;
			my @child_cmd = (@cmd, ("-x", $random_exclusive, '-c', $random_concurrency));
			push(@child_cmd, "--pid=$$");
			prnt("Requesting lock, x=$random_exclusive, $$\n");
			# my $child_cmd_text = join(' ', map { cmd_arg($_) } @child_cmd);
			system(@child_cmd);
			my $sleep_duration = $process_duration + ($process_duration_rand ? rand($process_duration_rand) : 0);
			prnt("Working for $sleep_duration sec, $$\n");
			Time::HiRes::sleep($sleep_duration); # Performing some task
			system(@release_cmd, "--pid=".$$) if ($release);
			prnt("Done PID: ".$$.", $random_exclusive, sec: ".(Time::HiRes::time() - $started_sec)."\n");
			exit(0); # The child is done
		}
	}

	while (@child_pids) { waitpid(shift(@child_pids), 0) } # Wait for every child to finish
}
CODE

my $arg_tests = shift(@ARGV);
$arg_tests =~ m{^--test=(.+)$} || die("No test specified with --test=<value>");
my $test_spec = $1;

run_tests($test_spec);
