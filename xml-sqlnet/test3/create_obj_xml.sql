

drop table obj_xml purge;

create table obj_xml (
	object_id number(12) not null,
	obj_xml_data xmltype,
	obj_char_data varchar2(4000)
)
/

