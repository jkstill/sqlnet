
--set arraysize 1000
prompt
prompt !! Must run as SYSDBA !!
prompt

col chardata format a80
col table_name format a30
set linesize 200 trimspool on
set pagesize 5000
set long 1000000

@tracefile_identifier 'XMLDATA-SDUBOTH'

@@set_event_10079
--@10046

select table_name, xmldata
from jkstill.xmltest_1
order by table_name
/

@get_tracefile

-- ensure trace file closes cleanly
exit
