
col value format a80
set linesize 200 trimspool on

select value from v$diag_info where name = 'Default Trace File'
/
