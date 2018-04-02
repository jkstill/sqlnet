
col bytes format 999,999,999,999

select blocks,
	(select block_size from dba_tablespaces where tablespace_name = ( select tablespace_name from user_tables where table_name = 'OBJ_XML')) * blocks bytes
from user_tables 
where table_name = 'OBJ_XML'
/
