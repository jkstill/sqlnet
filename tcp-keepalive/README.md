
# Oracle SQLNet and TCP Keepalive


Run these tests and trace with tshark

- Baselines
  - idle sqlplus session, keep alive enabled
  - idle sqlplus session, keep alive disabled
- Broken sessions
  - active sqlplus session, drop a packet with iptables
    - search for SQLNETDROPME
      - /home/jkstill/linux/iptables/SQLNET-Drop.md
	   - Evernote
  - active sqlplus session, kill the sqlplus process
  - active sqlplus session, kill the oracle server shadow process

## Baselines
### idle sqlplus session, keep alive enabled

From sqlplus, run get-curr-ospid.sql
Then on server:
 

```bash
[root@19c01 tcpdump]# netstat -tanelup | grep 2600
tcp6       0      0 192.168.1.192:1521      192.168.1.254:38288     ESTABLISHED 54321      90466      2600/oraclecdb01    
```

The port in this case is 32288

tshark on server:

cmd 

  38288 is port used by shadow proce

  tshark -i any -f "src port 38288 or dst port 38288"  | tee sqlnet.txt

tshark file:

  sqlplus-idle-keepalive-enabled-server.txt

tshark on client:

cmd 

  tshark -i any -f "src port 36992 or dst port 36992" | tee sqlnet.txt

tshark file:

  sqlplus-idle-keepalive-enabled-client.txt


### idle sqlplus session, keep alive disabled
##Broken sessions
### active sqlplus session, drop a packet with iptables
search for SQLNETDROPME
  /home/jkstill/linux/iptables/SQLNET-Drop.md
  Evernote
### active sqlplus session, kill the sqlplus process
### active sqlplus session, kill the oracle server shadow process


