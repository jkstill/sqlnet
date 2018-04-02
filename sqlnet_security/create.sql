
drop table sql92_security_test ;

create table sql92_security_test ( id number );
insert into sql92_security_test values(1);
insert into sql92_security_test values(2);
insert into sql92_security_test values(3);
insert into sql92_security_test values(4);

commit;

