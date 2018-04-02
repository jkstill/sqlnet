
select
	s.username,
	s.sid,
	p.spid spid
from v$session s, v$process p
where p.addr = s.paddr
	and userenv('SID') = s.sid
/

