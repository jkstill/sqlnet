
update obj_xml
set obj_char_data = xmlserialize(content obj_xml_data as clob)
/

