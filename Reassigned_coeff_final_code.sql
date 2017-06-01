

select X.Cat_key,x.Cluster_key,X.final_Co_eff_pos,y.final_Co_eff_first,z.final_Co_eff_further
into final_reassigned_coeff
from
(
select cat_key,cluster_key,
case when pos_pe between 0.005 and 0.05 then pos_pe
     when avg_pos_pe_cat between 0.005 and 0.05 then avg_pos_pe_cat
     when avg_pos_pe_dept between 0.005 and 0.05 then avg_pos_pe_dept 

---when (Co_efficient<0 and Co_efficient>0.5 and avg_co_eff_dept between 0 and 0.5) then avg_co_eff_dept
else -1
end as final_Co_eff_pos
from 
	(
	select b.*
	,avg_pos_pe_cat
	,avg_pos_pe_dept 
	from

		(
		select cat_key,avg(pos_pe) avg_pos_pe_cat
		from 
			(
			select * from temp_table_4
			where pos_pe between 0.005 and 0.05
			)a
		group by cat_key
		)a
	right join temp_table_4 b
	on a.cat_key=b.cat_key
	
	left join
	 
	(select dept_key,max(pos_pe) avg_pos_pe_dept from 
	(select dept_key,pos_pe,ntile(4) over(partition by dept_key order by pos_pe) quartile
		from 
			(
			select * from temp_table_4
			where pos_pe between 0.005 and 0.05
			)a
	        )a
    where quartile=2
	group by dept_key
    )c
	on b.dept_key=c.dept_key
	)a
)X
left join
(
select cat_key,cluster_key,
case when first_pe between 0.005 and 0.05 then first_pe
     when avg_first_pe_cat between 0.005 and 0.05 then avg_first_pe_cat
     when avg_first_pe_dept between 0.005 and 0.05 then avg_first_pe_dept 

---when (Co_efficient<0 and Co_efficient>0.5 and avg_co_eff_dept between 0 and 0.5) then avg_co_eff_dept
else -1
end as final_Co_eff_first
from 
	(
	select b.*
	,avg_first_pe_cat
	,avg_first_pe_dept 
	from

		(
		select cat_key,avg(first_pe) avg_first_pe_cat
		from 
			(
			select * from temp_table_4
			where first_pe between 0.005 and 0.05
			)a
		group by cat_key
		)a
	right join temp_table_4 b
	on a.cat_key=b.cat_key
	
	left join
	 
	(select dept_key,max(first_pe) avg_first_pe_dept from 
	(select dept_key,first_pe,ntile(4) over(partition by dept_key order by first_pe) quartile
		from 
			(
			select * from temp_table_4
			where first_pe between 0.005 and 0.05
			)a
	        )a
    where quartile=2
	group by dept_key
    )c
	on b.dept_key=c.dept_key
	)a
)Y
on x.Cat_key=y.Cat_key
and x.Cluster_key=y.Cluster_key
left join
(
select cat_key,cluster_key,
case when further_pe between 0.005 and 0.05 then further_pe
     when avg_further_pe_cat between 0.005 and 0.05 then avg_further_pe_cat
     when avg_further_pe_dept between 0.005 and 0.05 then avg_further_pe_dept 

---when (Co_efficient<0 and Co_efficient>0.5 and avg_co_eff_dept between 0 and 0.5) then avg_co_eff_dept
else -1
end as final_Co_eff_further
from 
	(
	select b.*
	,avg_further_pe_cat
	,avg_further_pe_dept 
	from

		(
		select cat_key,avg(further_pe) avg_further_pe_cat
		from 
			(
			select * from temp_table_4
			where further_pe between 0.005 and 0.05
			)a
		group by cat_key
		)a
	right join temp_table_4 b
	on a.cat_key=b.cat_key
	
	left join
	 
	(select dept_key,max(further_pe) avg_further_pe_dept from 
	(select dept_key,further_pe,ntile(4) over(partition by dept_key order by further_pe) quartile
		from 
			(
			select * from temp_table_4
			where further_pe between 0.005 and 0.05
			)a
	        )a
    where quartile=2
	group by dept_key
    )c
	on b.dept_key=c.dept_key
	)a
)Z
on x.Cat_key=z.Cat_key
and x.Cluster_key=z.Cluster_key
