

insert into emp_xml(employee_id, empdata)
SELECT e.employee_id,
	XMLELEMENT(
		"Emp",
   	XMLFOREST(
			e.employee_id
			, e.first_name
			, e.last_name
			, e.email
			, e.phone_number
			, e.hire_date
			, e.job_id
			, e.salary
			, e.commission_pct
			, m.last_name as mgr_last_name
			, m.first_name as mgr_first_name
			, d.department_name
		)
	) Emp_Element
FROM hr.employees e
join hr.departments d on d.department_id = e.department_id
left outer join hr.employees m on  m.employee_id = e.manager_id
/

