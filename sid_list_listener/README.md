
# Static Listener Configuration in Oracle SQL\*Net

Show the proper use of the SID_LIST_LISTENER section of listener.ora

For a long time now it has not been necessary to manually configure the databases instances in the listener.ora configuration file.

This is because the instance  dynamically register with the listener, a feature that was introduced many versions ago.

There are still cases where the static listener is required, which requires manually modifying the the SID_LIST_LISTENER section of listener.ora.

One such case is when duplicating a database via RMAN.  RMAN will stop and start the auxiliary instance several times. If that connection is made via a TNS connection, then the static listener entry is required.

Static listener entries are also required if you just need to remotely stop and start a database instance.


## SID_LIST_LISTENER configuration

For each LISTENER entry in listener.ora, there should be at most 1 SID_LIST_LISTENER section.

Listener Example 1 shows a simple listener configuration

Test Environment

- Server
  - Oracle Linux 6.5
  - Oracle 12.1.0.2
- Client
  - Linux Mint 18
  - Oracle 12.1.0.2 client

Listener Example 1.

```bash

LISTENER =
  (DESCRIPTION_LIST =
    (DESCRIPTION =
      (ADDRESS = (PROTOCOL = TCP)(HOST = localhost)(PORT = 1521))
      (ADDRESS = (PROTOCOL = IPC)(KEY = EXTPROC1521))
    )
  )

# static listener that allows remote logon when instance is down
SID_LIST_LISTENER =
  (SID_LIST =
    (SID_DESC =
      (ORACLE_HOME = /u01/app/oracle/product/12.1.0/db1 )
      (SID_NAME = js03)
    )
  )

```

With this configuration the db instance will show a status of 'UNKNOWN'.  This is normal.

```bash
LSNRCTL> status
Connecting to (DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=localhost)(PORT=1521)))
STATUS of the LISTENER
------------------------
Alias                     LISTENER
Version                   TNSLSNR for Linux: Version 12.1.0.2.0 - Production
Start Date                08-MAY-2019 12:17:57
Uptime                    0 days 0 hr. 0 min. 2 sec
Trace Level               off
Security                  ON: Local OS Authentication
SNMP                      OFF
Listener Parameter File   /u01/app/grid/product/12.1.0/grid/network/admin/listener.ora
Listener Log File         /u01/app/grid/diag/tnslsnr/ora12102b/listener/alert/log.xml
Listening Endpoints Summary...
  (DESCRIPTION=(ADDRESS=(PROTOCOL=tcp)(HOST=localhost)(PORT=1521)))
  (DESCRIPTION=(ADDRESS=(PROTOCOL=ipc)(KEY=EXTPROC1521)))
Services Summary...
Service "js03" has 1 instance(s).
  Instance "js03", status UNKNOWN, has 1 handler(s) for this service...
The command completed successfully
LSNRCTL>
```

A local TNS entry of 'js03dr' was made on the client side.

This was named with the suffix of 'dr' to make it a unique name, as 'js03' is a name that is normally resolved by LDAP.

The 'dr' suffix also helps to make clear the purpose of this tns entry.

See TNSNames Example 1

TNSNames Example 1

```bash
js03dr =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = 192.168.1.92)(PORT = 1521))
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SERVICE_NAME = js03)
    )
  )
```

Note: Tests were performed with and without including  ```(GLOBAL_NAME=js03)``` in the CONNECT_DATA section.  On this version of Oracle it made no difference either way.


The js03 instance is currently down on server 192.168.1.92.

With the static listener registration I can login remotely to start the database.

First verify this is a remote client:

```
>  ifconfig enp0s3
enp0s3    Link encap:Ethernet  HWaddr 08:00:27:81:0f:5a
          inet addr:192.168.1.254  Bcast:192.168.1.255  Mask:255.255.255.0
          inet6 addr: fe80::e031:6d65:4764:2634/64 Scope:Link
          UP BROADCAST RUNNING MULTICAST  MTU:1500  Metric:1
          RX packets:78048390 errors:0 dropped:0 overruns:0 frame:0
          TX packets:68963264 errors:0 dropped:0 overruns:0 carrier:0
          collisions:0 txqueuelen:1000
          RX bytes:44512415053 (44.5 GB)  TX bytes:68021269182 (68.0 GB)

>tnsping js03

TNS Ping Utility for Linux: Version 12.1.0.2.0 - Production on 08-MAY-2019 12:07:59

Copyright (c) 1997, 2014, Oracle.  All rights reserved.

Used parameter files:
/u01/app/oracle/product/12.1.0/c12/network/admin/sqlnet.ora

Used LDAP adapter to resolve the alias
Attempting to contact (DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=ora12102b.jks.com)(PORT=1521))(CONNECT_DATA=(SERVICE_NAME=pdbjs03.jks.com)))
OK (0 msec)


>  nslookup ora12102b.jks.com
Server:         127.0.1.1
Address:        127.0.1.1#53

Name:   ora12102b.jks.com
Address: 192.168.1.92
```

Now login remotely and start the database

```bash

>  sqlplus -L sys@js03dr as sysdba

SQL*Plus: Release 12.1.0.2.0 Production on Wed May 8 12:04:40 2019

Copyright (c) 1982, 2014, Oracle.  All rights reserved.

Enter password:
Connected to an idle instance.

SYS@js03dr AS SYSDBA> startup
ORACLE instance started.

Total System Global Area 1459617792 bytes
Fixed Size                  2924496 bytes
Variable Size             486539312 bytes
Database Buffers          956301312 bytes
Redo Buffers               13852672 bytes
Database mounted.
Database opened.
SYS@js03dr AS SYSDBA>

```

## Multiple Static Registrations

It is not uncommon for a server to have multiple databases, and so it may be necessary to have multiple static listener entries in the listener.ora file.

### The Correct Method

The correct way to do this when there is just one listener is to have multiple ```SID_LIST``` sections within ```SID_LIST_LISTENER```

Listener 2 Example

```bash
LISTENER =
  (DESCRIPTION_LIST =
    (DESCRIPTION =
      (ADDRESS = (PROTOCOL = TCP)(HOST = localhost)(PORT = 1521))
      (ADDRESS = (PROTOCOL = IPC)(KEY = EXTPROC1521))
    )
  )

SID_LIST_LISTENER =
  (SID_LIST =
    (SID_DESC =
      (ORACLE_HOME = /u01/app/grid/product/12.1.0/grid )
      (SID_NAME = +ASM)
    )
    (SID_DESC =
      (ORACLE_HOME = /u01/app/oracle/product/12.1.0/db1 )
      (SID_NAME = js03)
    )
  )
```

Here is lsnrctl status output for this configuration:

```bash
LSNRCTL> status
Connecting to (DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=localhost)(PORT=1521)))
STATUS of the LISTENER
------------------------
Alias                     LISTENER
Version                   TNSLSNR for Linux: Version 12.1.0.2.0 - Production
Start Date                08-MAY-2019 12:19:36
Uptime                    0 days 0 hr. 2 min. 44 sec
Trace Level               off
Security                  ON: Local OS Authentication
SNMP                      OFF
Listener Parameter File   /u01/app/grid/product/12.1.0/grid/network/admin/listener.ora
Listener Log File         /u01/app/grid/diag/tnslsnr/ora12102b/listener/alert/log.xml
Listening Endpoints Summary...
  (DESCRIPTION=(ADDRESS=(PROTOCOL=tcp)(HOST=localhost)(PORT=1521)))
  (DESCRIPTION=(ADDRESS=(PROTOCOL=ipc)(KEY=EXTPROC1521)))
Services Summary...
Service "+ASM" has 2 instance(s).
  Instance "+ASM", status UNKNOWN, has 1 handler(s) for this service...
  Instance "+ASM", status READY, has 1 handler(s) for this service...
Service "js03" has 1 instance(s).
  Instance "js03", status UNKNOWN, has 1 handler(s) for this service...
The command completed successfully
LSNRCTL>

```

The ASM instance has 2 handlers; the dynamically registered handler is READY, while the static handler is UNKOWN.

As the js03 instance is down (it was stopped again after the previous startup) the only handler that appears is the static registration, with a status of UNKNOWN.


### The Not so Correct Method

While multiple SID_LIST_LISTENER sections are allowed, doing so only works properly when multiple listeners are configured (more on this later)

But, what happens if multiple SID_LIST_LISTENER sections are configured for a single listener?

Let's try it and find out.









