
col tracefile new_value v_tracefile format a100
set linesize 200 trimspool on

select value tracefile from v$diag_info where name = 'Default Trace File'
/

host scp oracle@ora112304a:&&v_tracefile .

