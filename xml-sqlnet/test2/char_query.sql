
@@config
@@connect

set term on

set arraysize 1000
prompt
prompt !! Must run as SYSDBA !!
prompt

col chardata format a80
col table_name format a30
set linesize 200 trimspool on
set pagesize 5000
set long 1000000

@tracefile_identifier 'VARCHAR-10046'

@@set_event_10079
@10046

set term off
set timing on
spool char_query.log

select employee_id, empchar
from &&v_username..emp_xml
order by employee_id
/

spool off

set term on

@get_tracefile

-- ensure trace file closes cleanly
exit
