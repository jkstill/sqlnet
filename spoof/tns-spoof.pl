#!/usr/bin/env perl
#
# jdh, 5/29/2003 - pretend to be Oracle DB server to tnslsnr
# (mostly stolen from James W. Abendschan jwa@jammed.com)
#
# Added packet type recognition and response logic, client-"database" connect
# conversation, and sql query hand-off to obj_srvr running on DB server.
# jdh, 6/10/2003
#
# Modified to do "database" connect conversation with real DB to validate
# password, instead of spoofing.  jdh, 7/8/2004)


use strict;
use warnings;
use Socket;
use Carp;
use FileHandle;
use HTML::HeadParser;

use LWP::UserAgent; 


my $REP_LOOKUP_FILE = "/home/jkstill/oracle/sqlnet/spoof/tns_replies.txt";
my $CMD_LOOKUP_FILE = "/home/jkstill/oracle/sqlnet/spoof/tns_cmds.txt";
my $PKT_HDR_SIZE = 10;
my $MAX_LINESIZE = 2048;
my $MAX_PACKETSIZE = 2048;
select(STDOUT); $| = 1;

my $HOSTADDR = 'wilbur.wou.edu';
my $DB_OBJ_SRVR_LSNR_URL = 'https://banweb.ous.edu/wouprd/owa/wou_obj_srvr_lsnr.p_connect';
my $DB_OBJ_SRVR_LSNR_SERVER = 'banweb.ous.edu';
my $DB_OBJ_SRVR_LSNR_PROC = '/wouprd/owa/wou_obj_srvr_lsnr.p_connect';

#my $DB_OBJ_SRVR_LSNR_PASSWD = `cat secret_passwd_file`;  # not the real name!
my $DB_OBJ_SRVR_LSNR_PASSWD = '';
chomp $DB_OBJ_SRVR_LSNR_PASSWD;
my $REAL_DB_HOST = 'spruce.ous.edu';
my $REAL_DB_PORT = 1541;

# bytes 11 and 12 identifiy the command:  03 09 is DISCONNECT
my $LOGOUT_BYTES = '00 0D 00 00 06 00 00 00 00 00 03 09 24';

my $GOOD_LOGIN_ACK =    '00 38 00 00 06 00 00 00 00 00 04 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 03 00 00 00 00 00 00';

my $GOOD_LOGIN_ACK70 = '00 4a 00 00 06 00 00 00 00 00 04 01 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 03 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00';

my $OBJ_SRVR_USER_QRY = "select chk_obj_srvr_user(user) from dual";

# Actually this must represent the version of Net8 on the client, because some
# BI Query V. 7.0 return the '70' acks and some don't.
my $BI_QUERY_VERSION = '60';  # will reset if indicated by ACK

my $DEBUG = 0;

my ($reply, $acc_port, $checksum, $remote, $sock, $iaddr, $paddr, $line,
    $cmdlen, $cmdlenH, $cmdlenL, $packetlen, $packetlenH, $packetlenL,
    $command, $cmd_str, $cmd, @bytes, $bytes, $i, $name, @n, $n, $count,
    $db_port, %tns_cmds, %tns_replies, $fld1, $fld2, $CURR_CMD, $CONTEXT,
    $QUERY, @QUERY_RESULT, $NUM_COLS, $ROW_CNT, $RECORD_CNT, $SEQ, $envkey,
    @fh_out, @fh_in, $fd_out, $fd_in, $size, @beq_bytes, $redir_length,
    $redir_msg, $req, $BAD_LOGIN, $TNS_TYPE, $ua, $request, $response,
    $http_sock);

sub logmsg { return unless $DEBUG; 
             my $fh_out = shift; 
             print $fh_out "$0 $$: @_ at ", scalar localtime, "\n" }

# read in tns command and reply lookup files
read_config_files();


# thanks to Ian Redfern (ian.Redfern@logicaCMG.com) for NET8 Documentation
# jhjh - finish updating below to reflect this documentation
my %ora_pckt_types =
      # byte 11     byte 12
    ( 0x01 =>     { 0x05 => "CLIENT_TYPE",
                    0x06 => "HANDSHAKE2",
                    0x2C => "IDENT"        },

      0x02 =>     { 0x00 => "RESET",
                    0x01 => "CHAR_MAP"     },

      0x03 =>     { 0x02 => "SQL_OPEN",
                    0x03 => "QUERY",
                    0x04 => "QUERY_SECOND",
                    0x05 => "FETCH_MORE",
                    0x08 => "HANDSHAKE7",
                    0x09 => "DISCONNECT",
                    0x0E => "HANDSHAKE7",  # on purpose
                    0x27 => "SET_LANG",
                    0x2B => "DESC_COLS",
                    0x3B => "HANDSHAKE5",
                    0x47 => "FETCH",
                    0x51 => "USER_PASSWD",
                    0x52 => "CLIENT_ID",
                    0x54 => "HANDSHAKE4",
                    0x5E => "SQL",
                    0x73 => "AUTH2",
                    0x76 => "AUTH1"        },

      0x04 =>     { 0x00 => "ACK", 
                    0x01 => "ACK70" },

      0xDE =>     { 0xAD => "HANDSHAKE1"   }    );


# ============================================================================
#                                   Program
# ============================================================================
# =============================
#  Get Port for DB Connections 
# =============================
my $LSNR_PORT = 1521;  # WOU listener, need to register w/ listener if
                       # pre-spawn mode
my $DB_BASE_PORT = 33500;  # jhjh
my $DB_MAX_PORT = 33600;
my $proto = getprotobyname('tcp');

socket(Server, PF_INET, SOCK_STREAM, $proto) || die "socket: $!";
setsockopt(Server, SOL_SOCKET, SO_REUSEADDR, pack("l", 1))
   || die "setsockopt: $!";

$db_port = $DB_BASE_PORT;
until ( bind(Server, sockaddr_in($db_port, INADDR_ANY) ) ||
        $db_port++ > $DB_MAX_PORT ) { }

# open logfile
my $LOGFILE = "/tmp/oracle_$db_port.log";
if ($DEBUG) {
    open(LOG, ">$LOGFILE") or die "$!:  can't open $LOGFILE for output";
    select(LOG); $| = 1; select(STDOUT);

    `chmod 644 $LOGFILE`;
}

listen(Server,SOMAXCONN) || die "listen: $!";

logmsg \*LOG, "DB server started on port $db_port";

my $LOGIN = 0;

# ====================================
#  Handshake with Listener (BEQ mode)
# ====================================
# get reader pipe, writer pipe already opened by parent process (tnslsnr)
# (thanks, merlyn!)
@fh_in  = grep { defined($_) } map FileHandle->new_from_fd($_, "r"), 0..100;
@fh_out = grep { defined($_) } map FileHandle->new_from_fd($_, "w"), 0..100;
                                                   # assume listener won't
                                                   # more than 100 fd's open;
                                                   # this won't be true if
                                                   # we get very many users
                                                   # even on a dedicated lsnr

$size = @fh_in;
$fd_in = fileno( $fh_in[ $size - 2 ] );    # 2nd highest fd_in is reader pipe
                                           # (at least on this lsnr/platform)

$size = @fh_out;
$fd_out = fileno( $fh_out[ $size - 1 ] );  # highest fd_out is writer pipe

logmsg \*LOG, "fd_in = $fd_in, fd_out = $fd_out";

open(IN,  "<&=$fd_in");
open(OUT, ">&=$fd_out");

logmsg \*LOG, "after opening fd_in, fd_out";

select OUT; $| = 1;

print  OUT "NTP0 $$\n";

select STDOUT;

# pull in 3 messages from tnslsnr; only takes 2 reads
sysread(\*IN, $bytes, $MAX_LINESIZE);
logmsg \*LOG, "reply from tnslsnr: ", strings($bytes);

# sometimes it pulls in all 3 messages in first read
if ( strings($bytes) !~ /ADDRESS/ ) {
    sysread(\*IN, $bytes, $MAX_LINESIZE);
    logmsg \*LOG, "reply from tnslsnr: ", strings($bytes);
}

$cmd_str =  "(ADDRESS=(PROTOCOL=tcp)(HOST=$HOSTADDR)(PORT=$db_port))";

# Below is my deduction, have tested through the "10's" column, and
# contined into the 100's and 1000's but didn't provide a long enough
# following message to totally confirm.  Behaviour was consistent w/
# this idea through all 4 columns (jhjh).
#
# Since each byte can represent 255 symbols, the following length (for
# the message AFTER this message) is represented in the 4 bytes as given
# below (bigEndian format?):
# base 256   1's                       10's      100's     1000's
# base 10    0-255                     256 - 65535, etc.
# !!(above is true for linux)
# !!print  OUT   chr(length($cmd_str) ),   chr(0),   chr(0),   chr(0);

# for Solaris, it is littleEndian 
print  OUT   chr(0), chr(0), chr(0), chr(length($cmd_str) );

print  OUT   $cmd_str;


# ============================================================================
#                   accept connection from obj_srvr (may be remote)
# ============================================================================
socket(Obj_Srvr_Server, PF_INET, SOCK_STREAM, $proto) || die "socket: $!";
setsockopt(Obj_Srvr_Server, SOL_SOCKET, SO_REUSEADDR,
    pack("l", 1))   || die "setsockopt: $!";

until ( bind(Obj_Srvr_Server, sockaddr_in($db_port, INADDR_ANY) ) ||
        $db_port++ > $DB_MAX_PORT ) { }

($db_port > $DB_MAX_PORT) && die "bind: $!";

logmsg \*LOG, "sending POST to $DB_OBJ_SRVR_LSNR_URL, host = $HOSTADDR, port = $db_port\n";

# this will start (possibly) remote obj_srvr and then it will connect to us on $db_port
$ua = LWP::UserAgent->new;

# password-protected public OAS procedure that sends dbms_pipe message to
# (possibly) remote OS listener (for SCT Banner this is GURJOBS, the job
# submission listener), which starts dedicated obj_srvr
$ua->post( $DB_OBJ_SRVR_LSNR_URL, { pp_uid    => "obj_srvr",
                                    pp_passwd => $DB_OBJ_SRVR_LSNR_PASSWD,
                                    pp_host   => $HOSTADDR,
                                    pp_port   => $db_port } );

# jhjh - use this option if $ua->post is broken on your server 
# jhjh $request = HTTP::Request->new(POST => $DB_OBJ_SRVR_LSNR_URL);

# jhjh $request->content("pp_uid=obj_srvr&pp_passwd=$DB_OBJ_SRVR_LSNR_PASSWD&pp_host=$HOSTADDR&pp_port=$db_port");

# jhjh $response = $ua->request($request);

# if that is also broken, below will work but passes the lsnr password over
# unencrypted socket in plain text.

#!! not secure:  need to use https
# jhjh $http_sock = socket_connect($DB_OBJ_SRVR_LSNR_SERVER, 80);
# jhjh select($http_sock); $| = 1; select(STDOUT);
# jhjh print $http_sock "POST $DB_OBJ_SRVR_LSNR_PROC?pp_uid=obj_srvr&pp_passwd=$DB_OBJ_SRVR_LSNR_PASSWD&pp_host=$HOSTADDR&pp_port=$db_port\n";
# jhjh logmsg \*LOG, sysread($http_sock, $bytes, $MAX_LINESIZE);  # don't care about this
# jhjh close($http_sock);

# to make sure that obj_srvr doesn't try to connect before we're listening,
# the obj_srvr will try to connect 10 times w/ 2 second pauses in between.

logmsg \*LOG, "sent POST\n";
listen(Obj_Srvr_Server,SOMAXCONN)                   || die "listen: $!";

$paddr = accept(Obj_Srvr, Obj_Srvr_Server);
($acc_port,$iaddr) = sockaddr_in($paddr);
$name = gethostbyaddr($iaddr,AF_INET);

logmsg \*LOG, "connection from $name [", inet_ntoa($iaddr), "] at port $acc_port";

select(Obj_Srvr); $| = 1; select(STDOUT);

# ===========================================
# Listen for Client Connection to "Database"
# ===========================================
db_accept(\*Server);
logmsg \*LOG, "end of oracle\n";
close(LOG);


# ===========================================================================
#                                Subroutines
# ===========================================================================
sub db_accept {

    my $server_socket = shift;

    my ($bytes, $valid_login, $redir_host, $redir_port, $handshake_done, 
        $req_type, $state);

    logmsg \*LOG, "calling db_accept()";

    $paddr = accept(Client, $server_socket);
    ($acc_port,$iaddr) = sockaddr_in($paddr);
    $name = gethostbyaddr($iaddr,AF_INET);

    logmsg \*LOG, "connection from $name [", inet_ntoa($iaddr), "] at port $acc_port";

    $CONTEXT = "HANDSHAKE";
    $SEQ = 0;


    # jhjh - make connection to real production db here (at the sqlnet
    #        packet level), then pass along the client packets to this
    #        db, to let it do the password validation.  If it logs the
    #        user in, they are validated.  We log them out from that DB
    #        and continue.  Otherwise we disconnect them.  We will
    #        pass back the DB's replies to the client to keep the
    #        conversation going, all the way through login.  This means
    #        we don't need to spoof nearly as much (like we were doing
    #        with %ora_pckt_types).  We let the DB do that for us, to
    #        satisfy the client that it is connected to a real DB.  We
    #        accomplish this and the password validation in one step.
    #        all we have to do then is the more-or-less ascii text
    #        sql communication.  Whoa! 


    # jhjh - at this point we start talking to the real DB, and pass through
    #        all listener and client traffic.  The listener handshakes with
    #        the real DB (while we read and pass along the traffic), the
    #        client does the same, then when the client successfully logs in
    #        we close the real DB connection and take over.  Obj_srvr will
    #        make a new DB connection as user obj_srvr.  Will need to build
    #        in some object security to obj_srvr, so that different users can
    #        have different access.  For our purposes, it may be enough to
    #        control this through the client data model.  There is a valid
    #        obj_srvr user list in addition to the wouprd password, only
    #        those in the list can log in.

    # NOTE:  we want the client and Real DB to talk to each other, but not
    #        directly.  I.e. when the real DB sends us the redirect port,
    #        we change our real DB socket to that port, but the client still
    #        keeps talking on $db_port.  So we don't pass this redirect
    #        message on to the client.


    logmsg \*LOG, "connecting to real DB...\n";  # jhjh
    $sock = socket_connect($REAL_DB_HOST, $REAL_DB_PORT);
    $bytes = prepare_command( lookup_command($CMD_LOOKUP_FILE,
        "ESTABLISH_REAL_DB") );

    select($sock); $| = 1; select(Client); $| = 1; select(STDOUT);

    send_command($sock, $bytes);

    $valid_login = 0; $BAD_LOGIN = 0; $handshake_done = 0; $state = "";

    # handle REDIRECT from Real DB
    if ( sysread($sock, $bytes, $MAX_LINESIZE) ) {
        logmsg \*LOG, "DB:  $bytes\n";
        get_request_type($bytes);  # use to populate $TNS_TYPE 

        if ( $TNS_TYPE == 0x5                                 and
             strings($bytes) =~ /\(HOST=(.+)\)\(PORT=(\d+)\)/ and
             $redir_host = $1 and $redir_port = $2 ) {

            logmsg \*LOG, "reconnecting to DB at $redir_host on $redir_port\n";

            close($sock);
            $sock = socket_connect($redir_host, $redir_port);
            select($sock); $| = 1; select(STDOUT);

            # again, send connection request for real DB, not obj_srvr
            $bytes = prepare_command( lookup_command($CMD_LOOKUP_FILE,
                "ESTABLISH_REAL_DB") );
            send_command($sock, $bytes);

            logmsg \*LOG, "Did REAL_DB REDIRECT\n";

            # throw away Client's Redirect connect msg to $db_port,
            # let it get the ACK from REAL_DB
            if ( sysread(\*Client, $bytes, $MAX_LINESIZE) ) {
                logmsg \*LOG, "Client:  $bytes\n";
            }
        }
        else {
            die "Big problems";
        }
    }
    else {
        die "Big problems";
    }


    REAL_DB_LOOP:
    while ( sysread($sock, $bytes, $MAX_LINESIZE) ) {

        $req_type = get_request_type($bytes);  # track state
        logmsg \*LOG, "\$req_type is $req_type\n";
        logmsg \*LOG, "DB:  $bytes\n";
        print Client $bytes;

        if ($req_type eq "RESET") { 
            # Do another read from real DB - this is the real message;
            # the message from "while ( sysread(... " was just the ACK
            # to the BREAK.
            if ( sysread($sock, $bytes, $MAX_LINESIZE) ) {
                logmsg \*LOG, "DB:  $bytes\n";
                print Client $bytes;
            }
        }

        if ($BAD_LOGIN) {
            close($sock);
            last REAL_DB_LOOP;
        }

        if ( logged_in($state, $bytes) ) {
            $valid_login = 1;
            $state = "";
        }

        if ( $handshake_done ) {
            logmsg \*LOG, "checking if valid obj_srvr user\n";

            # must be in the list of obj_srvr users, not just have a DB login
            if ( !obj_srvr_user($sock) ) {
                $valid_login = 0;
                send_command(\*Client, lookup_command($REP_LOOKUP_FILE,
                    "INVALID_USER_PASS") );
            }

            logmsg \*LOG, "disconnecting from Real DB\n";
            send_command($sock, $LOGOUT_BYTES);
            last REAL_DB_LOOP;
        }

        if ( sysread(\*Client, $bytes, $MAX_LINESIZE) ) {
            if ( handshake_done($bytes) ) { $handshake_done = 1 }

            $req_type = get_request_type($bytes);  # track state

            if ($req_type eq "USER_PASSWD" ) {
                $state = $req_type;
            }
            print $sock $bytes;
            logmsg \*LOG, "Client:  $bytes\n";
        }
    }
    logmsg \*LOG, "outside REAL_DB_LOOP\n";
    if (sysread($sock, $bytes, $MAX_LINESIZE) ) {
        logmsg \*LOG, "Last DB Read:  $bytes\n";
    }
    close($sock);

    # send client an INVALID_USER_PASS if we're returning
    if (!$valid_login) {
        send_command(\*Client, lookup_command($REP_LOOKUP_FILE,
            "INVALID_USER_PASS") );
        close(Client);
        return;
    }

    # fall-through (we have a valid user/password)

    # Now we're speaking SQL (after a couple of handshake messages;
    # send_reply() will handle these.)
    while ( sysread(\*Client, $bytes, $MAX_LINESIZE) ) {
        logmsg \*LOG, "$bytes\n";
        send_reply(\*Client, $bytes);
    }
}

sub hexify {
    my $input = shift;
    my ($output, $i);
    for ($i=0; $i<length($input); $i++) {
        $output .= sprintf "%.2x ", ord(substr($input, $i, 1));
    }
    return $output;
}

sub hexdump {
    my $input = shift;
    my ($byte, $count, $output);

    ($byte) = unpack("C", $input);
    $count++;
    $output .= sprintf "%.2x ", $byte;

    while ( ($byte) = unpack("x$count C", $input) ) {
        $count++;
        $output .= sprintf "%.2x ", $byte;
    }

    $output =~ s/\s$//;

    return $output;
}

sub lookup_command {  # jdh
    my ($cmd_file, $cmd_keyword) = @_;


    if ( $BI_QUERY_VERSION eq '70' and
         $cmd_file =~ /replies/i   and
         exists($tns_replies{ $cmd_keyword . '70' } )  ) {
        $cmd_keyword .= '70';
    }

    logmsg \*LOG, "\nCOMMAND:  $cmd_keyword\n";  # jhjh

    if ($cmd_file =~ /cmds/i )    { return $tns_cmds{$cmd_keyword}    }
    if ($cmd_file =~ /replies/i ) { return $tns_replies{$cmd_keyword} }

}


sub socket_connect {
    my ($remote, $port) = @_;
    if ($port =~ /\D/) { $port = getservbyname($port, 'tcp') }
    die "No port" unless $port;
    $iaddr   = inet_aton($remote)               || die "no host: $remote";
    $paddr   = sockaddr_in($port, $iaddr);
    $proto   = getprotobyname('tcp');
    socket(SOCK, PF_INET, SOCK_STREAM, $proto)  || die "socket: $!";
    connect(SOCK, $paddr)    || die "connect: $!";
    select(SOCK); $| = 1; select(STDOUT);
    logmsg \*LOG, "Connected\n";

    return \*SOCK;
}

sub prepare_command {
    my $cmd_str = shift;

    my ($mode);

    $mode = shift or ($mode = "TCP");  # TCP is default, BEQ is for talking
                                       # to lsnr when lsnr running in bequeath
                                       # mode

    my $hdr_size =  $mode eq "TCP" ? 58 : 
                   ($mode eq "BEQ" ?  4 : 0);  # TCP header is 58 bytes,
                                               # BEQ header is  4 bytes

    $cmd_str =~ s/\$COLON/:/;
    $cmd_str =~ s/\$pid/$$/;
    $cmd_str =~ s/\$port/$db_port/;

    # calculate command length
    $cmdlen = length($cmd_str);
    $cmdlenH = $cmdlen >> 8;
    $cmdlenL = $cmdlen & 0xff;
    $cmdlenH = sprintf "%.2x", $cmdlenH;
    $cmdlenL = sprintf "%.2x", $cmdlenL;

    # calculate packet length
    $packetlen = length($cmd_str) + $hdr_size;
    $packetlenH = $packetlen >> 8;
    $packetlenL = $packetlen & 0xff;
    $packetlenH = sprintf "%.2x", $packetlenH;
    $packetlenL = sprintf "%.2x", $packetlenL;
    $cmd = hexify($cmd_str);

    # first 20 bytes is for tcp/ip I guess, next 38 bytes for tnslsnr and
    # it's attached server programs.
    # decimal offset
    # 0: packetlen_high packetlen_low 
    # 25: cmdlen_high cmdlen_low
    # 59: command
    # the packet:
    if ($mode eq "TCP") {
        $bytes="\
        $packetlenH $packetlenL 00 00 01 00 00 00 01 36 01 2c 00 00 08 00 \
        7f ff 7f 08 00 00 00 01 $cmdlenH $cmdlenL 00 3a 00 00 00 00 \
        00 00 00 00 00 00 00 00 00 00 00 00 34 e6 00 00 \
        00 01 00 00 00 00 00 00 00 00 $cmd";
    }
    elsif ($mode eq "BEQ") {
        $bytes="\
        $cmdlenH $cmdlenL 00 00 $cmd"; 

    }
    else { die  "prepare_command:  UNKNOWN MODE\n" } 

    return $bytes;
}

sub send_command {
    my ($sock, $bytes) = @_;
    my ($msg, $seqH, $seqL, $seq);

    $seqH = $SEQ >> 8;
    $seqL = $SEQ & 0xff;
    $seqH = sprintf "%.2x", $seqH;
    $seqL = sprintf "%.2x", $seqL;
    $seq = "$seqH $seqL";

    $bytes =~ s/\$seq/$seq/g;  # jhjh - 5/24/2004

    @n = split(" ", $bytes);
    $packetlen = @n;
    $count = 0;

    logmsg \*LOG, "\nwriting $packetlen bytes\n";

    while (@n) {
        $count++;
        $n = shift @n;
        if (length($n) == 2) {
            chomp $n;
            print $sock chr(hex($n));
            $msg .= chr(hex($n));
        }
        else { print "lost [$bytes]\n" }
    }

    print "\n|", strings($msg) ? strings($msg) : "", "|\n";

    logmsg \*LOG, "\nMessage checksum is %x\n", checksum($msg); 

    $count != $packetlen && print "Error:  bytes sent != packet length\n";
}

sub checksum {
    my $msg = shift;
    my $checksum = unpack("%C*", $msg);
    $checksum %= 65535;
    return $checksum;
}

sub send_reply {

    logmsg \*LOG, "\nCONTEXT = $CONTEXT\n";  # jhjh

    my ($socket, $msg) = @_;
    my ($text_msg, $bytes);

    $text_msg = strings($msg);

    if ($text_msg) { print "\ngot $text_msg from Client" }

    $reply = lookup_command($REP_LOOKUP_FILE, get_request_type($msg) );

    # Disconnect
    if ( $CURR_CMD eq "DISCONNECT") {
        close($socket);
        exit(0);
    }

    # Handshakes
    if ( $CONTEXT eq "HANDSHAKE" ) {
        if ( $CURR_CMD eq "DESC_COLS" ) {
            $CURR_CMD = "ORA_BANNER";
            $reply = lookup_command($REP_LOOKUP_FILE, $CURR_CMD );
        }
        elsif ( $CURR_CMD eq "FETCH" ) {
            $CURR_CMD = "USER_HS1";
            $reply = lookup_command($REP_LOOKUP_FILE, $CURR_CMD );
        }
        elsif ( $CURR_CMD eq "FETCH_MORE" ) {
            $CURR_CMD = "USER_HS2";
            $reply = lookup_command($REP_LOOKUP_FILE, $CURR_CMD );
        }
        else { }
    }

    # Query
    if ( $CURR_CMD eq "QUERY") {  # $CURR_CMD populated in get_request_type()
        if ( $text_msg =~ /SQLCQR_LOGINCHECK/i ||
             $text_msg =~ /BANNER/i            ||
             $text_msg =~ /ACCESSIBLE_TABLES/i  ) {
            $CURR_CMD = "SESSION";
            $reply = lookup_command($REP_LOOKUP_FILE, $CURR_CMD );
        }
        else {
            $CONTEXT = "QUERY";
            $ROW_CNT = 0;

            logmsg \*LOG, "calling get_query\n";  # jhjh
            $QUERY = get_query($msg);
            logmsg \*LOG, "Query is:  $QUERY\n";  # jhjh

        }
    } 

    # Query Follow-up
    if ($CONTEXT eq "QUERY") {
        if ( $CURR_CMD eq "DESC_COLS" ||
             $CURR_CMD eq "FETCH"     ||
             $CURR_CMD eq "FETCH_MORE" ) {

            if ( $CURR_CMD eq "DESC_COLS" ) {
                # pass query to obj_srvr
                do_query($QUERY, $socket);  # populates @QUERY_RESULT
            }

            $reply = prepare_ora_reply(\@QUERY_RESULT, $CURR_CMD);
            # note:  prepare_ora_reply removes data from @QUERY_RESULT as it
            # prepares it.  (It may take many fetch/reply's to return all
            # the data in @QUERY_RESULT.  Some or all of an array element
            # (a record) may be returned and removed.)
        }
    }

    # Send Reply
    if ($reply) {
        $reply =~ s/\s+/ /sg;  # clean up for display (and for send)
        $reply = uc($reply);

        print "Sending the following to Client:  $reply";
        $SEQ++;
        send_command($socket, $reply);
        logmsg \*LOG, "$reply\n";

        # send ora_err packet after user_hs1 packet
        if ($CURR_CMD eq "USER_HS1") {
            $reply = lookup_command($REP_LOOKUP_FILE, "SESSION_ORAERR" );
            $reply =~ s/\s+/ /sg;  # clean up for display
            $reply = uc($reply);
            print "Sending the following to Client:  $reply";
            $SEQ++;
            send_command($socket, $reply);
            logmsg \*LOG, "$reply\n";
        }
    }
}

sub get_request_type {
    my $msg = shift;

    my ($id_byte1, $id_byte2, $body, $pckt_type, $logmsg, $lenH, $lenL);

    ($lenH, $lenL, $TNS_TYPE, $id_byte1, $id_byte2) = 
        unpack("C C x2 C x5 C C", $msg);

    if ( defined($id_byte1) && defined($id_byte2) &&
         # jhjh !! make sure we want this
         $lenL != 0x00 && $lenH != 0x0b ) {  # in case short messages
                                             # concatenated by read

        $logmsg = sprintf("\nPACKET RECEIVED:  TNS_TYPE = $TNS_TYPE, byte 11 = %x, byte 12 = %x\n",
                  $id_byte1, $id_byte2);
        logmsg \*LOG, $logmsg; 

        $pckt_type = $ora_pckt_types{$id_byte1}->{$id_byte2};

        $CURR_CMD = $pckt_type;

        return $pckt_type;
    }
    else {
        logmsg \*LOG, "\nSHORT PACKET RECEIVED\n";  # jhjh
        $CURR_CMD = "SHORT_PACKET";
        if ( $id_byte1 == 0x01 ) { return "BREAK" }
        if ( $id_byte1 == 0x02 ) { return "RESET" }
    }

    # fall-through
    return "UNKNOWN";
}

sub read_config_files {

    $/ = ";";

    open(IN, "<$CMD_LOOKUP_FILE")  || die "$!:  cannot open $CMD_LOOKUP_FILE for reading";

    while ( <IN> ) {
        chomp;

        /:/ || next;

        ($fld1, $fld2) = split(/:/, $_);

        $fld1 =~ s/^\s*//g;
        $fld1 =~ s/\s*$//g;
        $fld2 =~ s/^\s*//g;
        $fld2 =~ s/\s*$//g;

        $tns_cmds{$fld1} = $fld2;
    }

    close(IN);

    open(IN, "<$REP_LOOKUP_FILE")  || die "$!:  cannot open $REP_LOOKUP_FILE for reading";

    while ( <IN> ) {
        chomp;

        /:/ || next;

        ($fld1, $fld2) = split(/:/, $_);

        $fld1 =~ s/^\s*//g;
        $fld1 =~ s/\s*$//g;
        $fld2 =~ s/^\s*//g;
        $fld2 =~ s/\s*$//g;

        $tns_replies{$fld1} = $fld2;
    }

    close(IN);

    $/ = "\n";
}

sub unix_line255 {

    my $str = shift;

    my ($pos, $space_pos, $str_254, $new_str);

    for ( $pos = 0; !defined($str_254) || $pos <= length($str); $pos += 254 ) {

        $str_254 = substr($str, $pos, 254);

        $space_pos = rindex($str_254, " "); 

        if ($space_pos != -1) {

            substr($str_254, $space_pos, 1) = "\n";
        }

        $new_str .= $str_254;
    }

    return $new_str;
}


sub strings {
    my $msg = shift;

    my ($count, $byte, $string);

    $count = 0;

    while ( ($byte) = unpack("x$count C", $msg) ) {

        $count++;

        if ( $byte >= 32 && $byte <= 126 ) {
            $string .= chr($byte);
        }
    }

    return $string;
}

sub get_query {

    my $msg = shift;

    my ($len, $query, $skip);

    # the real DB's version of oracle sends sql in 64-byte blocks preceded 
    # by a length-byte.
    $skip = 23;
    $len = unpack("x$skip C", $msg); $skip++;
    logmsg \*LOG, "first \$len is $len\n";  # jhjh

    while ( $len == 64 ) {
        $query .= unpack("x$skip Z$len", $msg);
        $skip += $len;
        $len = unpack("x$skip C", $msg); $skip++;
        logmsg \*LOG, "\$len is $len, \$query is $query\n";  # jhjh
    }
    $query .= unpack("x$skip Z$len", $msg);  # get partial block at end

    logmsg \*LOG, "\$query is $query\n";  # jhjh

    return unix_line255($query . ";");

}

sub do_query {

    my ($query, $socket) = @_;

    my ($buf, $c, $i, $record, $last_part_of_rec);

    print Obj_Srvr "sql\n";

    print "\nsent sql mode request to Obj_Srvr\n";  # jhjh

    $last_part_of_rec = "";

    REPLY_LOOP:
    while ( sysread(\*Obj_Srvr, $buf, $MAX_LINESIZE) ) {

        # sysread will pull in whatever's there, doesn't care where \n is;
        # so we need to break $buf into records delimited by \n.

        $record = $last_part_of_rec;

        for ($i = 0; $i < length($buf); $i++) {

            $c = substr($buf, $i, 1);
    
            if ( $c eq "\n" ) {  

                logmsg \*LOG, "$record\n";
                print "\nReading from Obj_Srvr:  got $record\n";  # jhjh
           
                if ( $record =~ /^QUIT$/ ) {
                    logmsg \*LOG, "sending disconnect to client\n";
                    send_command($socket, $LOGOUT_BYTES);
                    close($socket);
                    exit(0);
                }

                if ( $record =~ /^SQL> $/ ) {
                    print "\nGot SQL > Prompt from Obj_Srvr\n";  # jhjh
                    print Obj_Srvr "$query\n";
                }

                $record =~ s/^\s+//g;
                $record =~ s/\s+$//g;
                if ($record                    &&
                    $record !~ /rows returned/ &&
                    $record !~ /^SQL>$/ ) {
                    push @QUERY_RESULT, $record;
                }

                last REPLY_LOOP
                    if ($record && $record =~ /^\d+\s+rows returned$/ );

                # fall-through
                $last_part_of_rec = "";
                $record           = "";
            }
            else { $record .= $c }

        }  # for loop

        $last_part_of_rec = $record;  # maybe didn't get a '\n', or
                                      # didn't end on a '\n'
    }
}

sub prepare_ora_reply {

    my ($ra_query_result, $cmd) = @_;

    my ($bytes, @bytes, $pckt_len, $replenH, $replenL);

    $bytes = get_reply_data($ra_query_result, $cmd);

    @bytes = split(" ", $bytes);

    $pckt_len = @bytes;
    $pckt_len += 2;
    $replenH = $pckt_len >> 8;
    $replenL = $pckt_len & 0xff;
    $replenH = sprintf "%.2x", $replenH;
    $replenL = sprintf "%.2x", $replenL;

    $bytes = "$replenH $replenL" . $bytes;

    return $bytes;
}

sub get_reply_data {
    my ($ra_query_result, $cmd) = @_;

    my ($bytes, @bytes, $len, $lenH, $lenL, $footer, $col_desc, $row_cntH,
        $row_cnt_bytes, $row_cnt_bytes_str, $low_bytes, $row_cnt_str,
        $col_size, $rec_cnt, @columns, $col_name, $col_names, $packet_size,
        $record, $col_data, $save_len, $seqH, $seqL);

    if ( $cmd eq "DESC_COLS" ) {

        # obj_srvr returns column data delimited by '|'
        @columns = split /\|/, shift @QUERY_RESULT;
        $NUM_COLS = @columns;
        $NUM_COLS = sprintf("%.2x", $NUM_COLS);

        $bytes = " 00 00 06 00 00 00 00 00 08 $NUM_COLS 00 $NUM_COLS";

        $col_names = "";

        COL_DESC_LOOP:
        while ( $col_desc = shift @columns ) {
print "\ncol_desc = $col_desc\n";  # jhjh
            $save_len = length($bytes);  # so we can roll back to this
                                         # if we exceed packet length

            ($col_name, $col_size) = split /:/, $col_desc;

            $lenH = $col_size >> 8;
            $lenL = $col_size & 0xff;
            $lenH = sprintf "%.2x", $lenH;
            $lenL = sprintf "%.2x", $lenL;

            # jhjh 02 at byte 3 might mean number; 80 must mean varchar2.

            # size of column in DB is held in $lenH $lenL
            if ( $BI_QUERY_VERSION eq '60' ) {
                $bytes .= "
                00 01 80 00 $lenH $lenL 00 00 00 00 00 00 00 00 00 00
                00 00 00 00 00 00 00 01 00 01 00 0C 00 00 00 00
                00 00 00 00 00 00 00";
            }
            elsif ( $BI_QUERY_VERSION eq '70' ) {
                $bytes .= "
                00 01 80 00 $lenH $lenL 00 00 00 00 00 00 00 00 00 00
                00 00 00 00 00 00 00 01 00 01 $lenL 00 00 00 00 0C
                00 00 00 00 00 00 00 00 00 00 00";
            }


            # ($bytes keeps growing due to ".=" above - check size)
            @bytes = split(" ", $bytes);
            $packet_size = @bytes;  $packet_size += length($col_names) +
                                                    length($col_name)  + 1 + 4;
                                                 # add in missing first two
                                                 # bytes + extra two at end

            if ( $packet_size > $MAX_PACKETSIZE ) {
                $bytes = substr($bytes, 0, $save_len - 1);
                last COL_DESC_LOOP;
                # jhjh - Need to see what the drill is if you can't send
                # the whole col desc in a single packet.  Does the client
                # send another request, or do you send another packet
                # unprompted?
            }

            $col_names .= $col_name . "\"";
        }

        $col_names = hexify($col_names);

        @bytes = split(" ", $col_names);
        $len = @bytes;
        $lenH = $len >> 8;
        $lenL = $len & 0xff;
        $lenH = sprintf "%.2x", $lenH;
        $lenL = sprintf "%.2x", $lenL;

        # length of column names string is held in $lenH $lenL
        $bytes .= " $lenH $lenL $lenH $lenL $col_names 09";
        if ( $BI_QUERY_VERSION eq '70' ) { $bytes .= " 05 00 00 00" }

        # in case we couldn't send whole record 
        $record = "";
        foreach $col_desc (@columns) {
            $record .= $col_desc . "|";
        }

        if (@columns) {
            $record =~ s/\|$//;
            unshift @QUERY_RESULT, $record;  # save cols-to-send
                                             # on @QUERY_RESULT
        }

        else { 
            shift @QUERY_RESULT;  # throw away column header line
            $RECORD_CNT = @QUERY_RESULT;
        }
    }  # if ( $cmd eq "DESC_COLS" )

    else {

        $ROW_CNT++;

        $seqH = $SEQ >> 8;
        $seqL = $SEQ & 0xff;
        $seqH = sprintf "%.2x", $seqH;
        $seqL = sprintf "%.2x", $seqL;
        

        if ( $ROW_CNT == 1 ) {

            if ( $BI_QUERY_VERSION eq '60' ) {
                $row_cnt_bytes = 13;  # just to make packet size calculation
                                     # below come out right
                # jhjh - does not handle more than FF FF FF FF rows since
                # byte 13 = 04
                $footer = " 00 08 02 00 00 00 00 00 00 00 00 40 04 01 00 00
                            00 00 00 00 00 00 00 01 00 00 00 03 00 20 00 00
                            00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
                            00 00 $seqH $seqL 00 00 01 00 00 00 00 00 00 00 00 00
                            00";
            }
            elsif ( $BI_QUERY_VERSION eq '70' ) {
                $row_cnt_bytes = 12;  # just to make packet size calculation
                                     # below come out right
                # jhjh - does not handle more than FF FF FF FF rows since
                # byte 12 = 04

                $footer = " 00 08 02 00 00 00 00 00 00 00 00 40 04 05 00 00
                            00 01 00 00 00 00 00 00 00 00 00 01 00 00 00 03
                            00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
                            00 00 00 00 00 00 $seqH $seqL 00 00 01 00 00 00 00 00
                            00 00 00 00 00 00 00 00 00 00 00 00";
            }
        }
        else {

            $row_cnt_bytes = (sprintf "%d", log($ROW_CNT) / log(256) ) + 1;
            $low_bytes = $row_cnt_bytes - 1;

            $row_cntH = $ROW_CNT; $row_cnt_str = ""; 
                             # get high byte
            while ( $low_bytes >= 0 ) {  

                $row_cntH >>= (8 * $low_bytes);

                # prefix it (followed by a space) to $row_cnt_str
                $row_cnt_str = (sprintf " %.2x", $row_cntH) . $row_cnt_str; 

                # get rid of high byte that we just prefixed to $row_cnt_str
                $row_cntH = $ROW_CNT & ( (256 ** $low_bytes) - 1);

                $low_bytes--;
            }

            $row_cnt_bytes_str .= sprintf "%.2x", $row_cnt_bytes;

            # $row_cnt_str may be 1 or more space-delimited bytes
            for ( $row_cnt_bytes_str .. 04 ) { $row_cnt_str .= " 00" }
            $row_cnt_bytes_str = "04";  # this limits us to FF FF FF FF
                                        # (4,294,967,295) rows

            if ( $BI_QUERY_VERSION eq '60' ) {
                #$footer = " 00 $row_cnt_bytes_str $row_cnt_str
                #            00 00 00 00 00 00 01 00 00 00 03 00 20 00 00 00
                #            00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
                #            00 $seqH $seqL 00 00 01 00 00 00 00 00 00 00";

                # jhjh - don't send row count until we figure out why the
                # client displays the last row twice.
                $footer = " 00 $row_cnt_bytes_str 00 00 00 00
                            00 00 00 00 00 00 01 00 00 00 03 00 20 00 00 00
                            00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
                            00 $seqH $seqL 00 00 01 00 00 00 00 00 00 00";
            }
            elsif ( $BI_QUERY_VERSION eq '70' ) {
                # jhjh - don't send row count until we figure out why the
                # client displays the last row twice.
                $footer = "
                00 $row_cnt_bytes_str 05 00 00 00 02 00 00 00 00 00 00 00 00 00
                01 00 00 00 03 00 00 00 00 00 00 00 00 00 00 00
                00 00 00 00 00 00 00 00 00 00 00 $seqH $seqL 00 00 01
                00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
                00";
            }
        }

        if ($ROW_CNT > $RECORD_CNT ) {  # all data returned

            # NO DATA FOUND
            if ( $BI_QUERY_VERSION eq '60' ) {
                # 05 7B = 01403 (Oracle error code for no data found):
                # this is in bytes 14 and 15 (low byte first)
                return " 00 00 06 00 00 00 00 00 04 00 00 00 00 7B 05 00
                         00 00 00 01 00 00 00 03 00 40 00 00 00 00 00 00
                         00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 32
                         00 00 01 00 00 00 19 4F 52 41 2D 30 31 34 30 33
                         3A 20 6E 6F 20 64 61 74 61 20 66 6F 75 6E 64 0A";
            }

            elsif ( $BI_QUERY_VERSION eq '70' ) {
                # 05 7B = 01403 (Oracle error code for no data found):
                # this is in bytes 18 and 19 (low byte first)
                return " 00 00 06 00 00 00 00 00 04 05 00 00 00 01 00 00
                         00 7B 05 00 00 00 00 01 00 00 00 03 00 00 00 00
                         00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
                         00 00 00 29 00 00 01 00 00 00 00 00 00 00 00 00
                         00 00 00 00 00 00 00 00 19 4F 52 41 2D 30 31 34
                         30 33 3A 20 6E 6F 20 64 61 74 61 20 66 6F 75 6E
                         64 0A";
            }
        }

        # fall-through

        if ( $BI_QUERY_VERSION eq '60' ) {
            $bytes = " 00 00 06 00 00 00 00 00 06 02 00 00 00 00 01 00
                       00 00 07";
                    # " 00 00 06 00 00 00 00 00 06 02 02 00 00 00 01 00
                    #   00 00 07";
        }

        elsif ( $BI_QUERY_VERSION eq '70' ) {
            $bytes = " 00 00 06 00 00 00 00 00 06 02 04 00 00 00 01 00
                       00 00 00 00 00 00 00 00 00 00 07";
        }

        @columns = split /\|/, shift @QUERY_RESULT, -1;
                                                    # keep trailing nulls

        COL_DATA_LOOP:
        while (defined($col_data = shift @columns) ) {

            # handle null values
            if (!$col_data and
                $col_data ne 0) {
              
                $lenL = sprintf "%.2x", 2;

                # hex 05 7D = 1405:  Oracle error code for "fetched column
                # value is NULL"
                $col_data = hexify( chr(0x05) . chr(0x7D) );
            }
            else { 
                $len = length($col_data);
                $lenH = $len >> 8;
                $lenL = $len & 0xff;
                $lenH = sprintf "%.2x", $lenH;
                $lenL = sprintf "%.2x", $lenL;
       
                $save_len = length($bytes);     

                $col_data = hexify($col_data);
            }

            # length of column data is held in $lenL  (where is lenH?)
            # (I guess lenH could be the second "00" below, but the very
            # first field doesn't have a place for this in the packets
            # I've seen in the log file.)
            $bytes .= " $lenL $col_data  00 00";

            @bytes = split(" ", $bytes);
            $packet_size = @bytes;  $packet_size += (50 + $row_cnt_bytes);
                                                 # add in footer size plus
                                                 # missing first two bytes

            if ( $packet_size > $MAX_PACKETSIZE ) {
                $bytes = substr($bytes, 0, $save_len - 1);
                last COL_DATA_LOOP;
            }
        }

        $bytes = substr($bytes, 0, length($bytes) - 3);  # remove last "00"       
        $bytes .= "$footer";
       
        # in case we couldn't send whole record 
        $record = "";
        foreach $col_data (@columns) {
            $record .= $col_data . "|";
        }
        if (@columns) {
            $record =~ s/\|$//;
            unshift @QUERY_RESULT, $record;
            $ROW_CNT--;
        }
    }

    return $bytes;
}

sub logged_in {
    my ($state, $bytes) = @_;

    my ($req_type);

    if ($state eq "USER_PASSWD") {
        logmsg \*LOG, "state = USER_PASSWD\n";
        $req_type = get_request_type($bytes);

        if ( $req_type =~ /ACK|ACK70/ ) {

            if ($req_type eq "ACK70") { 
                $GOOD_LOGIN_ACK = $GOOD_LOGIN_ACK70;
                $BI_QUERY_VERSION = '70';
            }

            logmsg \*LOG, "state = USER_PASSWD, getting ACK\n";
            logmsg \*LOG, hexdump($bytes), "\n";
            logmsg \*LOG, $GOOD_LOGIN_ACK, "\n";

            if ( hexdump($bytes) eq $GOOD_LOGIN_ACK ) {
                logmsg \*LOG, "GOOD_LOGIN";
                return 1;
            }
            else {
                logmsg \*LOG, "BAD_LOGIN";
                $BAD_LOGIN = 1;
            }
        }
    }

    # fall-through
    return 0;
}

sub handshake_done {
    my $bytes = shift;

    if ( strings($bytes) =~ /alter session set NLS_DATE_FORMAT/i ) { 
            return 1;
    }

    # fall-through
    return 0;
}

sub obj_srvr_user {
    my $real_db = shift;

    my ($qry_hdr, $len, $lenH, $lenL, $qry_len_plus_1, $qry_hex, $bytes,
        $valid_obj_srvr_user);

    $qry_len_plus_1 = length($OBJ_SRVR_USER_QRY) + 1;
           # header is 23
    $len = 23 + $qry_len_plus_1;  # plus 1 for linefeed on the end

    $lenH = $len >> 8;
    $lenL = $len & 0xff;

    # now "hex format" the lengths
    $qry_len_plus_1 = sprintf "%.2x", $qry_len_plus_1;
    $lenH = sprintf "%.2x", $lenH;
    $lenL = sprintf "%.2x", $lenL;

    # has 23 bytes
    $qry_hdr = "$lenH $lenL 00 00 06 00 00 00 00 00 03 03 13 01 00 00
                00 01 40 00 00 00 $qry_len_plus_1";

    $qry_hex = $qry_hdr . " " . hexify($OBJ_SRVR_USER_QRY) . " 0a";

    # =======================================================================
    #  Send a sequence of commands in order to send $qry_hex and get results
    # =======================================================================
    send_command($real_db, lookup_command($REP_LOOKUP_FILE, "HANDSHAKE7_2_CMD") );
    sysread($real_db, $bytes, $MAX_LINESIZE) or return 0;  # get ACK
    logmsg \*LOG, "DB, for HANDSHAKE7_2_CMD:  $bytes\n";

    send_command($real_db, lookup_command($REP_LOOKUP_FILE, "HANDSHAKE7_CMD") );
    sysread($real_db, $bytes, $MAX_LINESIZE) or return 0;  # get ACK
    logmsg \*LOG, "DB, for HANDSHAKE7_CMD:  $bytes\n";

    send_command($real_db, lookup_command($REP_LOOKUP_FILE, "SQL_OPEN_CMD") );
    sysread($real_db, $bytes, $MAX_LINESIZE) or return 0;  # get ACK 
    logmsg \*LOG, "DB, for SQL_OPEN_CMD:  $bytes\n";

    # send valid_user query 
    send_command($real_db, $qry_hex);
    logmsg \*LOG, "$0:  $qry_hex\n";
    sysread($real_db, $bytes, $MAX_LINESIZE) or return 0;  # get ACK
    logmsg \*LOG, "DB, for Query:  $bytes\n";

    send_command($real_db, lookup_command($REP_LOOKUP_FILE, "QUERY_SECOND_CMD") );
    sysread($real_db, $bytes, $MAX_LINESIZE) or return 0;  # get ACK 
    logmsg \*LOG, "DB, for QUERY_SECOND_CMD:  $bytes\n";

    send_command($real_db, lookup_command($REP_LOOKUP_FILE, "DESC_COLS_CMD") );
    sysread($real_db, $bytes, $MAX_LINESIZE) or return 0;  # get col desc
    logmsg \*LOG, "DB, for DESC_COLS_CMD:  $bytes\n";

    if ($BI_QUERY_VERSION eq '60') {
        send_command($real_db, lookup_command($REP_LOOKUP_FILE, "FETCH_CMD") );
    }
    elsif ($BI_QUERY_VERSION eq '70') {
        send_command($real_db, lookup_command($REP_LOOKUP_FILE, "FETCH_CMD70") );
    }

    $valid_obj_srvr_user = 0;

    if ( sysread($real_db, $bytes, $MAX_LINESIZE) ) {
        logmsg \*LOG, "DB, for FETCH_CMD:  $bytes\n";

        if (strings($bytes) =~ /valid_obj_srvr_user/i ) {
            $valid_obj_srvr_user = 1;
        }

        return $valid_obj_srvr_user;

    }
}
