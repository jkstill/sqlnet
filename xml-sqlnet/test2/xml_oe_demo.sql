SELECT warehouse_name warehouse,
   warehouse2."Water", warehouse2."Rail"
   FROM oe.warehouses,
   XMLTABLE('/Warehouse'
      PASSING warehouses.warehouse_spec
      COLUMNS
         "Water" varchar2(6) PATH '/Warehouse/WaterAccess',
         "Rail" varchar2(6) PATH '/Warehouse/RailAccess')
      warehouse2
/
