
update emp_xml
set empchar = xmlserialize(content empdata as clob)
/

