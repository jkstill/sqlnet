
@clears

col newline newline

set pages 0 feed off term on serverout on size 1000000 line 200

spool dblink_original.sql

select '--' from dual;
select '-- script to recreate original database links if needed ' from dual;
select '--' from dual;

select 'set pages 0 feed on term on echo on' from dual;

select 
	'@c2 jkstill/' || instance ,
	'drop public database link ' || db_link || ';' newline,
	'create public database link ' || db_link || ' connect to ' || username ||
		' identified by ' || password || ' using ' || '''' ||
		host || '''' || ';' newline
from db_links
/

select 'set pages 24 feed on term on echo off' from dual;

spool off

spool v2_link.sql

select '--' from dual;
select '-- recreate database links using SQLNET Version 2 instead of Version 1 ' from dual;
select '--' from dual;

select 'set pages 0 feed on term on echo on' from dual;
select 'whenever sqlerror exit 1' from dual;
select 'spool v2_link.log' from dual;

select 'col cauth new_value uauth noprint' from dual;
select 'col global_name format a20' from dual;

select 'set term off echo off' from dual;
select 'select auth cauth from oid@rp01 where instance = ' || '''' || 'db01' || '''' || ';' from dual;
select 'set term on echo on' from dual;
select 'set sqlprompt ' || '''' || ''''  from dual;

set define off

select 
	'connect jkstill/&&uauth@' || instance newline,
	'select ' || '''' || 'DATABASE: ' || '''' || ' ||global_name  from global_name;' newline,
	'drop public database link ' || db_link || ';' newline,
	'create public database link ' || db_link || ' connect to ' || username ||
		' identified by ' || password || ' using ' || '''' ||
		substr(host,instr(host,':',-1,1)+1) ||
		'''' || ';' newline,
		-- now test the link
		'select count(*) from all_tables@' || db_link || ';' newline
from db_links
/

set define on

select 'spool off' from dual;
select 'set pages 24 feed on term on echo off' from dual;
select 'whenever sqlerror continue' from dual;
select '@c2 jkstill/dv07' from dual;

spool off

set pages 24 feed on term on echo off

@c2 jkstill/dv07


