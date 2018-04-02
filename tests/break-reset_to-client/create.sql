

-- br = break-reset
drop table br_test purge;

create table br_test (
	id number(3) not null,
	c1 varchar2(10),
	c2 varchar2(5)
)
/

create index br_test_pk_idx on br_test(id);

alter table br_test add constraint br_test_pk primary key (id);


