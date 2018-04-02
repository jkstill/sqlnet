--
-- recreate database links using SQLNET Version 2 instead of Version 1
--
set pages 0 feed on term on echo on
whenever sqlerror exit 1
spool v2_link.log
col cauth new_value uauth noprint
col global_name format a20
set term off echo off
select auth cauth from oid@rp01 where instance = 'db01';
set term on echo on
set sqlprompt ''
connect jkstill/&&uauth@DB01
select 'DATABASE: ' ||global_name  from global_name;
drop public database link CEDPR02.BCBSO.BENCHMARK.ORG;
create public database link CEDPR02.BCBSO.BENCHMARK.ORG connect to EMC identified by EMCDBA2 using 'pr02';
select count(*) from all_tables@CEDPR02.BCBSO.BENCHMARK.ORG;

connect jkstill/&&uauth@DV01
select 'DATABASE: ' ||global_name  from global_name;
drop public database link EMC.DV02;
create public database link EMC.DV02 connect to EMCLINK identified by EMCLINK2 using 'dv02';
select count(*) from all_tables@EMC.DV02;

connect jkstill/&&uauth@DV03
select 'DATABASE: ' ||global_name  from global_name;
drop public database link EMCPR02.BCBSO.BENCHMARK.ORG;
create public database link EMCPR02.BCBSO.BENCHMARK.ORG connect to EMC identified by EMCDBA2 using 'pr02';
select count(*) from all_tables@EMCPR02.BCBSO.BENCHMARK.ORG;

connect jkstill/&&uauth@DV04
select 'DATABASE: ' ||global_name  from global_name;
drop public database link EMCPR02.BCBSO.BENCHMARK.ORG;
create public database link EMCPR02.BCBSO.BENCHMARK.ORG connect to EMC identified by EMCDBA2 using 'pr02';
select count(*) from all_tables@EMCPR02.BCBSO.BENCHMARK.ORG;

connect jkstill/&&uauth@DV05
select 'DATABASE: ' ||global_name  from global_name;
drop public database link EMCPR02.BCBSO.BENCHMARK.ORG;
create public database link EMCPR02.BCBSO.BENCHMARK.ORG connect to EMC identified by EMCDBA2 using 'pr02';
select count(*) from all_tables@EMCPR02.BCBSO.BENCHMARK.ORG;

connect jkstill/&&uauth@PR02
select 'DATABASE: ' ||global_name  from global_name;
drop public database link EMC.DB01;
create public database link EMC.DB01 connect to EMCLINK identified by EMCLINK1 using 'db01';
select count(*) from all_tables@EMC.DB01;

connect jkstill/&&uauth@PR03
select 'DATABASE: ' ||global_name  from global_name;
drop public database link CED_DB01.BCBSO.BENCHMARK.ORG;
create public database link CED_DB01.BCBSO.BENCHMARK.ORG connect to CED identified by CEDDBA1 using 'db01';
select count(*) from all_tables@CED_DB01.BCBSO.BENCHMARK.ORG;

connect jkstill/&&uauth@PR03
select 'DATABASE: ' ||global_name  from global_name;
drop public database link DB01.BCBSO.BENCHMARK.ORG;
create public database link DB01.BCBSO.BENCHMARK.ORG connect to USSLINK identified by ORADBA1 using 'db01';
select count(*) from all_tables@DB01.BCBSO.BENCHMARK.ORG;

connect jkstill/&&uauth@PR03
select 'DATABASE: ' ||global_name  from global_name;
drop public database link EMC.PR02;
create public database link EMC.PR02 connect to EMCLINK identified by EMCLINK2 using 'pr02';
select count(*) from all_tables@EMC.PR02;

spool off
set pages 24 feed on term on echo off
whenever sqlerror continue
@c2 jkstill/dv07
