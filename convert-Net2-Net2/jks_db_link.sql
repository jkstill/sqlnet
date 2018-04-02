
col owner  format a10
col db_link format a30
col host format a15
col connect_id format a10
col password format a10


select 
	u.name owner, 
	l.name db_link, 
	l.userid connect_id, 
	l.host host, 
	l.password password
from sys.link$ l, sys.user$ u
where l.owner# = u.user#
/
