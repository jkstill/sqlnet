
@@config

drop table &&v_username..xmltest_2 purge;

create table &&v_username..xmltest_2 (filename varchar2(64), xmldata XMLType, clobdata clob, chardata varchar2(4000))
pctfree 10 pctused 10 initrans 1 maxtrans 1 storage (initial 8k) lob (clobdata)
store as lobseg (
	disable storage in row
	chunk 16384 pctversion 10 cache storage (initial 2m)
	index lobidx_clobdata ( storage (initial 4k))
)
/


