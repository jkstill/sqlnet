


insert into obj_xml(object_id, obj_xml_data)
SELECT e.object_id,
        XMLELEMENT(
                "Object",
        XMLFOREST(
                        e.owner
                        , e.object_name
                        , e.subobject_name
                        , e.object_id
                        , e.data_object_id
                        , e.created
                        , e.last_ddl_time
                        , e.timestamp
                        , e.status
                        , e.temporary
                        , e.generated
                        , e.secondary
								, e.namespace
								, e.edition_name
                )
        ) Obj_Element
FROM dba_objects e
where rownum <= 1000
/

