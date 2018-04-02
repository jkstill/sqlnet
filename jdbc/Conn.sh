#!/bin/bash

export CLASSPATH=$ORACLE_HOME/jdbc/lib/ojdbc6.jar:/home/oracle/app/oracle/product/11.2.0/jlib:./

$ORACLE_HOME/jdk/bin/javac Conn.java

/usr/bin/java Conn



