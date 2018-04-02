

drop table db_links;

create table
db_links (
	instance varchar2(4) not null,
	db_link varchar2(50) not null,
	owner varchar2(30) not null,
	host varchar2(40) not null,
	username varchar2(30) not null,
	password varchar2(20) not null
)
/

insert into db_links( instance, db_link, owner, host, username, password )
values('DB01', 'CEDPR02.BCBSO.BENCHMARK.ORG', 'PUBLIC', 't:aslan:pr02', 'EMC', 'EMCDBA2');

insert into db_links( instance, db_link, owner, host, username, password )
values('DV01', 'EMC.DV02', 'PUBLIC', 'T:beowulf:dv02', 'EMCLINK', 'EMCLINK2');

insert into db_links( instance, db_link, owner, host, username, password )
values('DV03', 'EMCPR02.BCBSO.BENCHMARK.ORG', 'PUBLIC', 't:aslan:pr02', 'EMC', 'EMCDBA2');

insert into db_links( instance, db_link, owner, host, username, password )
values('DV04', 'EMCPR02.BCBSO.BENCHMARK.ORG', 'PUBLIC', 't:aslan:pr02', 'EMC', 'EMCDBA2');

insert into db_links( instance, db_link, owner, host, username, password )
values('DV05', 'EMCPR02.BCBSO.BENCHMARK.ORG', 'PUBLIC', 't:aslan:pr02', 'EMC', 'EMCDBA2');

insert into db_links( instance, db_link, owner, host, username, password )
values('PR02', 'EMC.DB01', 'PUBLIC', 'T:aslan:db01', 'EMCLINK', 'EMCLINK1');

insert into db_links( instance, db_link, owner, host, username, password )
values('PR03', 'CED_DB01.BCBSO.BENCHMARK.ORG', 'PUBLIC', 'T:aslan:db01', 'CED', 'CEDDBA1');

insert into db_links( instance, db_link, owner, host, username, password )
values('PR03', 'DB01.BCBSO.BENCHMARK.ORG', 'PUBLIC', 't:aslan:db01', 'USSLINK', 'ORADBA1');

insert into db_links( instance, db_link, owner, host, username, password )
values('PR03', 'EMC.PR02', 'PUBLIC', 't:aslan:pr02', 'EMCLINK', 'EMCLINK2');

commit;

