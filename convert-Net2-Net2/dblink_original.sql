--
-- script to recreate original database links if needed
--
set pages 0 feed on term on echo on
@c2 jkstill/DB01
drop public database link CEDPR02.BCBSO.BENCHMARK.ORG;
create public database link CEDPR02.BCBSO.BENCHMARK.ORG connect to EMC identified by EMCDBA2 using 't:aslan:pr02';

@c2 jkstill/DV01
drop public database link EMC.DV02;
create public database link EMC.DV02 connect to EMCLINK identified by EMCLINK2 using 'T:beowulf:dv02';

@c2 jkstill/DV03
drop public database link EMCPR02.BCBSO.BENCHMARK.ORG;
create public database link EMCPR02.BCBSO.BENCHMARK.ORG connect to EMC identified by EMCDBA2 using 't:aslan:pr02';

@c2 jkstill/DV04
drop public database link EMCPR02.BCBSO.BENCHMARK.ORG;
create public database link EMCPR02.BCBSO.BENCHMARK.ORG connect to EMC identified by EMCDBA2 using 't:aslan:pr02';

@c2 jkstill/DV05
drop public database link EMCPR02.BCBSO.BENCHMARK.ORG;
create public database link EMCPR02.BCBSO.BENCHMARK.ORG connect to EMC identified by EMCDBA2 using 't:aslan:pr02';

@c2 jkstill/PR02
drop public database link EMC.DB01;
create public database link EMC.DB01 connect to EMCLINK identified by EMCLINK1 using 'T:aslan:db01';

@c2 jkstill/PR03
drop public database link CED_DB01.BCBSO.BENCHMARK.ORG;
create public database link CED_DB01.BCBSO.BENCHMARK.ORG connect to CED identified by CEDDBA1 using 'T:aslan:db01';

@c2 jkstill/PR03
drop public database link DB01.BCBSO.BENCHMARK.ORG;
create public database link DB01.BCBSO.BENCHMARK.ORG connect to USSLINK identified by ORADBA1 using 't:aslan:db01';

@c2 jkstill/PR03
drop public database link EMC.PR02;
create public database link EMC.PR02 connect to EMCLINK identified by EMCLINK2 using 't:aslan:pr02';

set pages 24 feed on term on echo off
