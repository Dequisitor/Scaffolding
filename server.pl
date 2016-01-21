#!/usr/bin/perl

package server;

use strict;
use warnings;
use Term::ANSIColor;
use Socket;

my $port = 3000;
my $protocol = getprotobyname("tcp");

#extract request body from socket
#main problem is that there is no terminating charachter at the end of the last line, and the read functions just wait
#going to read content length, and after the header we will read a precise lenght, not whole lines
sub getRequestBody{
	my $handle = $_[0];
	my $contentLength = 0;

	while (<$handle>) {
		if (length($_) > 15 and substr($_, 0, 14) eq "Content-Length") {
			($contentLength = substr($_, 15)) =~ s/\s//;
		}

		if ($_ eq "\r\n") {
			last;
		}
	}

	my $reqBody;
	read($handle, $reqBody, $contentLength, 0);

	return $reqBody;
}

#check subdirectories
print "routes: \n";
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

print "server ready, listening on port $port\n";

my $client;
my $clientAddr;
while ($clientAddr = accept($client, SOCK)) {
	my ($port, $addr) = sockaddr_in($clientAddr);
	$addr = inet_ntoa($addr);
	print "\n---------------------------------\nConnection accepted from $addr:$port\n";
	my @request = split(" ", scalar <$client>);
	my $requestBody = getRequestBody($client);
	my $path = $request[1];
	print "request recieved: @request\n";
	print "request body: $requestBody\n";
	if (@request == 0) {
		next;
	}

	#default request a.k.a. no-route, should be 404 (filter strangers/intruders)
	if ($path eq "/") {
		print color("green");
		print "200 Request served without error\n";
		print color("reset");
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
				print "unable to import module: $@\n";
				print $client "HTTP/1.1 404 ERROR\r\n\r\n<h1>UNABLE TO LOAD MODULE $moduleName</h1><h2>$@</h2>";
			};
		}

		#handle request
		if (exists $INC{$servers{$moduleName}}) {
			(my $innerPath = $request[1]) =~ s/\/$moduleName//; #delete module name from request path
			my $return;
			eval {
				$return = $moduleName->handleRequest($client, $request[0], $innerPath, $requestBody);
				1;
			};

			if (!$@ && $return eq "OK") {
				print color("green");
				print "200 $moduleName: success\n";
				print color("reset");
			} else {
				print color("red");
				print "404 $moduleName: $return\n";
				print "exception: $@\n";
				print color("reset");

				print $client "HTTP/1.1 404 ERROR\r\n\r\n<h1>404 $return</h1>";
            }
		}
	} else {
		print color("red");
		print "404 $moduleName: module not found\n";
		print color("reset");

		print $client "HTTP/1.1 404 ERROR\r\n\r\n<h1>404 module not found</h1>";
		}
} continue {
	close $client;
	print "connection closed\n";
}
