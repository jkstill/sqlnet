
drop table emp_xml purge;

create table emp_xml (
	employee_id number(6) not null,
	empdata xmltype,
	empchar varchar2(4000)
)
/



