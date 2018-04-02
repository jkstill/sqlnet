drop database link js03_from_js02;

create database link js03_from_js02 connect to scott identified by tiger using '(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=192.168.1.47)(PORT=1521))(CONNECT_DATA=(SERVER=DEDICATED)(SERVICE_NAME=js03)))'
/
