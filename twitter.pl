#!/usr/bin/perl

##
# Nagios twitter notifier
#
# Requirements: Bundle::CPAN, Net::Twitter
# Usage: ./twitter.pl -m "your message here"
#
# Script will split messages into 140 character chunks and send a direct message for each chunk
# to each user in the users list
# 
# User needs to follow the sender in order for the message to be sent
#
# To get the token data, you will need to login to https://dev.twitter.com/apps and create an
# Application with full read/write/dm access
#
# Author: Matthew Spurrier
# Copyright: 2013 onwards Matthew Spurrier, All rights reserved
# License: http://www.gnu.org/copyleft/gpl.html GNU GPL v3 or later
##

##
# Start configuration
#
# Array of users to receive message
##
my @users   = ('User');

##
# Authentication Details
##

# Token
my $t_key   = '';

# Token Secret
my $t_sec   = '';

# Consumer Key
my $c_key   = '';

# Consumer Secret
my $c_sec   = '';

##
# End Configuration
#
# Start Application, do not edit below this line
##

use strict;
use warnings;
use Getopt::Std;
use Text::Wrap;
my %args;
getopts('m:', \%args);

# Twitter object
use Net::Twitter;
my $twitter = Net::Twitter->new(
    traits              => [qw/API::RESTv1_1/],
    consumer_key        => $c_key,
    consumer_secret     => $c_sec,
    access_token        => $t_key,
    access_token_secret => $t_sec,
);

# Ensure that we have a message to send
if (!$args{m}) {
    exit 1;
}

# We have a message, lets break it up into 140 character chunks
$Text::Wrap::columns = 140;
my @messages = split("\n",fill('','',$args{m}));
my $message;
my $user;

# For each user, send our messages
foreach $user (@users) {
    foreach $message (@messages) {
        # Send direct message
        $twitter->new_direct_message({
            screen_name     => "$user",
            text            => "$message",
        });
    }
}
