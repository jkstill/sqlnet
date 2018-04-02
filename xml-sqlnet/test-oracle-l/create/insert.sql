
@@config

insert into &&v_username..xmltest_2(filename, xmldata)
with data as (
select rownum id, column_value filename
from (
table(
sys.odcivarchar2list(
@@filelist.sql
)
)
)
)
select d.filename 
	, XMLType(bfilename('XMLDIR', d.filename), nls_charset_id('AL32UTF8') )
from data d
/

update &&v_username..xmltest_2 set clobdata = XMLType.getClobVal(xmldata);
update &&v_username..xmltest_2 set chardata = substr(XMLType.getClobVal(xmldata),1,4000);

commit;

