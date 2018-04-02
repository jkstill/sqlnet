
insert into xmltest_1(table_name, filename, xmldata)
with data as (
	select 
		table_name
		, lower(table_name) || '.xml' filename
	from dba_tables
	where owner = 'JKSTILL'
	and table_name not like 'XML%'
)
select d.table_name
	, d.filename 
	, XMLType(bfilename('XMLTEST', d.filename), nls_charset_id('AL32UTF8') )
from data d
/

update xmltest_1 set chardata = XMLType.getStringVal(xmldata);

commit;

