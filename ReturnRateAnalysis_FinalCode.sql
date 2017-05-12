use TPC_Arcadia;

select Dept_desc ,cat_key ,cat_desc --,line 
,MD_PERIOD_FLAG 
,avg(weeks_in_sales) as weeks_in_sales
,sum(net_sales_units) as net_sales_units 
,sum(gross_sales_units) as gross_sales_units
,(sum(gross_sales_units)-sum(net_sales_units)) as Return_Units
,case when sum(md_units) = 0 then 0 
else sum(MD_disc_weighted)*1.0/sum(md_units) end as MD_disc_weighted
,case when sum(gross_sales_units) = 0 then 0 
else sum(gross_sales_dollars)*1.0/sum(gross_sales_units) end as avg_price
,case when sum(full_price_units) = 0 then 0 
else sum(full_price_weighted)*1.0/sum(full_price_units) end as weighted_Full_price
from 
(
select Dept_desc,cat_key ,cat_desc,line,MD_PERIOD_FLAG,count(distinct concat(fiscal_year,fiscal_week)) as weeks_in_sales
,sum(net_sales_units) as net_sales_units ,sum(gross_sales_units) as gross_sales_units
,sum(gross_sales_dollars) as gross_sales_dollars
,sum(gross_sales_units * coalesce(md_discount,0))*1.0 as MD_disc_weighted
,sum(case when md_discount is null or md_discount=0 then 0 else gross_sales_units end) as md_units
,sum(gross_sales_units * coalesce(full_price,0))*1.0 as full_price_weighted
,sum(case when full_price is null or full_price=0 then 0 else gross_sales_units end) as full_price_units
from 
(
select *,
case when coalesce(md_taken_flag,pos_flag) is null then 0
else 1
end as MD_PERIOD_FLAG
from 
	(select *,LEAD(md_taken_flag,2) 
	over(partition by merchandise_key order by fiscal_year,fiscal_week) as pos_flag
	from
	[dbo].[Final_master_AD_2]
	where merchandise_key is not null
	) a
	)a
group by Dept_desc ,cat_key ,cat_desc,line,MD_PERIOD_FLAG
) a
--where cat_key=14930
group by Dept_desc ,cat_key ,cat_desc --, line 
,MD_PERIOD_FLAG



