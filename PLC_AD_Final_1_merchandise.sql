select *
from
(
select *
              ,max(case when row_n =1 then inventory else -1 end) over()+sum(net_sales_units) over() First_inv
              ,(max(case when row_n =1 then inventory else -1 end) over()+sum(net_sales_units) over())
                     -coalesce(lag(units) over(partition by merchandise_key order by fiscal_year,fiscal_week),0) strt_week_inv
              ,sum(NET_SALES_UNITS) over(partition by merchandise_key order by fiscal_year,fiscal_week)*1.0/
                     (max(case when row_n =1 then inventory else -1 end) over()+sum(net_sales_units) over()) SELL_TR
from
(select MERCHANDISE_KEY,FISCAL_YEAR,FISCAL_WEEK,NET_SALES_UNITS,inventory
,row_number() over(partition by merchandise_key order by fiscal_year desc,fiscal_week desc) row_n
,sum(net_sales_units) over(partition by merchandise_key 
              order by fiscal_year,fiscal_week) units
from final_master_AD_2
) a
)X
left join
(
select 
merchandise_key,
age_weeks
from
(
select 
B.MERCHANDISE_KEY,
(((2016-max(B.LAUNCH_YEAR))*52)+(37-max(B.LAUNCH_WEEK))) as age_weeks
from
		(
		select A.FISCAL_YEAR,A.FISCAL_WEEK,A.Cat_key,A.MERCHANDISE_KEY, 
		LEFT(A.launch_date,4) AS LAUNCH_YEAR,RIGHT(A.launch_date,2) AS LAUNCH_WEEK
		from
			(
			select *
			from [dbo].[final_master_AD_2]
			where MERCHANDISE_KEY is not null
			)A
		)B
		group by merchandise_key	
)C		
)Y
on X.merchandise_key = Y.merchandise_key
