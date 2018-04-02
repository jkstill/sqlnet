

/*
 10079, 00000, "trace data sent/received via SQL*Net"
 *Cause:
 *Action: level 1 - trace network ops to/from client
          level 2 - in addition to level 1, dump data
          level 4 - trace network ops to/from dblink
          level 8 - in addition to level 4, dump data
*/

-- all attempts to set with alter session result in ora-0131 insufficient privileges
--alter session set events '10079 trace name context forever, level 2';
oradebug setmypid
oradebug event 10079 trace name context forever, level 2

