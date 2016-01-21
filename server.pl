#!/usr/bin/perl

package server;

use strict;
use warnings;
use Term::ANSIColor;
use Socket;

my $port = 3000;
my $protocol = (getprotobyname("tcp"))[2];

#extract request body from socket
#main problem is that there is no terminating charachter at the end of the last line, and the read functions just wait
#going to read content length, and after the header we will read a precise length, not whole lines
sub getRequestBody{
	my $handle = $_[0];
	my $contentLength = 0;
	my $reqBody = '';

	my $line;
	while (!eof($handle)) {
		defined ($line = <$handle>) or die "readline error $!\n";

		if (length($line) > 15 and substr($line, 0, 14) eq "Content-Length") {
			($contentLength = substr($line, 15)) =~ s/\s//;
		}

		if ($line eq "\r\n") {
			last;
		}
	}

	read($handle, $reqBody, $contentLength, 0) if $contentLength>0;

	return $reqBody;
}

sub Log{
	my $str = $_[0];
	my $color = "reset";
	if (scalar(@_) > 1) {
		$color = $_[1];
	}
	my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = localtime(time);
	my $timestamp = sprintf("%02d-%02d-%04d %02d:%02d:%02d", $mday, $mon+1, $year+1900, $hour, $min, $sec);

	print color("yellow");
	print "[$timestamp]: ";
	print color($color);
	print "$str\n"
}

#check subdirectories
Log("routes: \n");
my %servers;
my $dirls = `ls -d */`;
my @dirs = split(" ", $dirls);
foreach my $dir (@dirs) {
	my $filels = `ls $dir/*.pm`;
	my @files = split(" ", $filels);
	foreach my $file (@files) {
		my $fileName = $file;
		if (-e ($fileName) and -s $fileName > 10) { #package xxx -> 11 length
			my ($fileHandle, $packageName, @line, $line);
			open($fileHandle, "<$fileName");
			$line = <$fileHandle>;
			close($fileHandle);
			my $fileData = do {
				local $/ = undef;
				open(my $fh, "<$fileName");
				<$fh>;
			};
			if ($line =~ /package\ \S+?;/ and $fileData =~ /sub\ init/ and $fileData =~ /sub\ handleRequest/) {
				($packageName = $line) =~ s/package\ (\S+?);\s*$/$1/g;
				$servers{$packageName} = $fileName;
				print "server: ";
				print color("yellow");
				print "/$packageName";
				print color("reset");
				print " at " ;
				print color("yellow");
				print "$fileName\n";
				print color("reset");
			}
		}
	}
}
print "\n";

#create socket
socket(SOCK, PF_INET, SOCK_STREAM, $protocol)
	or die "couldn't open a socket: $!";

setsockopt(SOCK, SOL_SOCKET, SO_REUSEADDR, 1)
	or die "couldn't set socket options: $!";

bind(SOCK, sockaddr_in($port, INADDR_ANY))
	or die "couldn't bind socket to port $port: $!";

listen(SOCK, SOMAXCONN)
	or die "couldn't listen to port $port: $!";

Log("server ready, listening on port $port\n");

my $client;
my $clientAddr;
while ($clientAddr = accept($client, SOCK)) {
	my ($port, $addr) = sockaddr_in($clientAddr);
	$addr = inet_ntoa($addr);
	Log("Connection accepted from $addr:$port", "cyan");

	my $reqSize = $client;
	my $requestStr = <$client>;
	next if !defined $requestStr;

	my @request = split(" ", $requestStr);
	my $requestBody = getRequestBody($client);
	my $path = $request[1];
	Log("request recieved: @request");
	Log("request body: $requestBody");
	next if @request == 1;

	#default request a.k.a. no-route, should be 404 (filter strangers/intruders)
	if ($path eq "/") {
		Log("200 Request served without error", "green");
		print $client "HTTP/1.1 404 RESOURCE NOT FOUND\r\n\r\n<html><body><h1>404 page not found</h1></body></html>\r\n";
		next;
	}

	my @path = split("/", $path);
	my $moduleName = $path[1];
	#check for module existance
	if (exists($servers{$moduleName})) {

		#is module already loaded?
		if (!exists $INC{$servers{$moduleName}}) {
			eval {
				require $servers{$moduleName};
				$moduleName->import();
				$moduleName->init();
				1;
			} or do {
				Log("unable to import module: $@");
				print $client "HTTP/1.1 404 ERROR\r\n\r\n<h1>UNABLE TO LOAD MODULE $moduleName</h1><h2>$@</h2>";
			};
		}

		#handle request
		if (exists $INC{$servers{$moduleName}}) {
			(my $innerPath = $request[1]) =~ s/\/$moduleName//; #delete module name from request path
			my $return = '';
			eval {
				Log("calling handleRequest in module $moduleName");
				$return = $moduleName->handleRequest($client, $request[0], $innerPath, $requestBody);
				Log("execution successfull");
				1;
			} or do {
				Log("exception: $@");
			};

			if ($return eq "OK") {
				Log("200 $moduleName: success", "green");
			} else {
				Log("404 $moduleName: $return", "red");

				print $client "HTTP/1.1 404 ERROR\r\n\r\n<h1>404 $return</h1>";
			}
		}
	} else {
		Log("404 $moduleName: module not found", "red");

		print $client "HTTP/1.1 404 ERROR\r\n\r\n<h1>404 module not found</h1>";
	}
} continue {
	close $client;
	undef $clientAddr;
	Log("connection closed", "cyan");
}
