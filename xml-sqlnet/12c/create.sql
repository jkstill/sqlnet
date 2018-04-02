
drop table jkstill.precache_test purge;

create table jkstill.precache_test
as
select * 
from dba_objects
/

exec dbms_stats.gather_table_stats('JKSTILL','PRECACHE_TEST');


