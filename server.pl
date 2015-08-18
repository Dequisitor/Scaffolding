#!/usr/bin/perl

package server;

use strict;
use warnings;
use Term::ANSIColor;
use Socket;

my $port = 3000;
my $protocol = getprotobyname("tcp");

#check subdirectories
print "routes: \n";
my %servers;
my $ls = `ls -d */`;
my @dirs = split(" ", $ls);
foreach my $dir (@dirs) {
    my $fileName = $dir . "server.pm";
    if (-e ($fileName) and -s $fileName > 10) { #package xxx -> 11 length
        my ($fileHandle, $packageName, @line, $line);
        open($fileHandle, "<". $fileName);
        $line = <$fileHandle>;
        @line = split(" ", $line);
        if ($line[0] eq "package") {
            ($packageName = $line[1]) =~ s/;$//;
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
        close $fileHandle;
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
    my $path = $request[1];
    print "request recieved: @request\n";

    if (@request == 0) {
        next;
    }

    if ($path eq "/") {
        print color("green");
        print "200 Request served without error\n";
        print color("reset");
        print $client "HTTP/1.1 404 RESOURCE NOT FOUND\r\n\r\n<html><body><h1>404 page not found</h1></body></html>\r\n";
        next;
    } 

    my @path = split("/", $path);
    my $moduleName = $path[1];
    if (exists($servers{$moduleName})) {

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

        if (exists $INC{$servers{$moduleName}}) {
            (my $innerPath = $request[1]) =~ s/\/$moduleName//;
            my $return = $moduleName->handleRequest($client, $request[0], $innerPath);

            if ($return eq "OK") { 
                print color("green");
                print "200 $moduleName: success\n";
                print color("reset");
            } else {
                print color("red");
                print "404 $moduleName: $return\n";
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
