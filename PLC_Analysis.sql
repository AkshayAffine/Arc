
/* ---------  Product Life Cycle Analysis --------- */

--## Creating All weeks & products table
use TPC_Arcadia;
drop table if exists all_wk_line_base;
--select count(*) from 
select * 
into all_wk_line_base
from 
(select dept_key, dept_desc ,cat_key ,Cat_Desc ,line 
from [dbo].[Final_master_AD_2]
where line is not null
group by dept_key, dept_desc ,cat_key ,Cat_Desc ,line ) a  --36891
cross join
(select FISCAL_YEAR ,FISCAL_WEEK
from [dbo].[Final_master_AD_2]
where FISCAL_YEAR is not null or FISCAL_WEEK is not null
group by FISCAL_YEAR ,FISCAL_WEEK ) b --136
;

--## Table with other metrics like sales

drop table if exists Inv_and_metrics_table;
select distinct dept_key ,dept_desc ,cat_key ,Cat_Desc ,line 
,FISCAL_YEAR ,FISCAL_WEEK ,launch_date ,MD_FLag ,MD_TAKEN_flag  
,STORE_NUM_WITH_INVENTORY ,STORE_NUM_WITH_ONORDER
,GROSS_SALES_UNITS ,NET_SALES_UNITS ,EOP_DC_Inventory_Units ,EOP_DC_On_Order_Units ,EOP_INVENTORY_UNITS 
,EOP_ON_ORDER_UNITS 
,FIRST_VALUE(coalesce(EOP_DC_Inventory_Units,0)+coalesce(EOP_DC_On_Order_Units,0)+coalesce(EOP_INVENTORY_UNITS,0)+coalesce(EOP_ON_ORDER_UNITS,0)+coalesce(Net_SALES_UNITS,0)) over(partition by line order by fiscal_year ,fiscal_week)
 as First_wk_inv
,MAX((cast(FISCAL_YEAR as int)*100 + cast(FISCAL_WEEK as int))) 
over(partition by line , case when md_flag is null then 'Reg' else 'MD' end) as md_max_date
into Inv_and_metrics_table
from [dbo].[final_master_AD_2]
where FISCAL_YEAR is not null and FISCAL_WEEK is not null
--where line=1442235
;


--Checks
select count(*) from Inv_and_metrics_table
select * from Inv_and_metrics_table where launch_date is null

select * from Inv_and_metrics_table where first_wk_inv is null

select * from Inv_and_metrics_table where line=1695202
order by FISCAL_YEAR ,FISCAL_WEEK


select top 200 * 
from [dbo].[final_master_AD_2]
where line=1442235
order by FISCAL_YEAR ,FISCAL_WEEK
;



--## Joining other metrics like sales to base table


drop table if exists PLC_AD;
--select count(*) from (
select a.dept_key ,a.dept_desc ,a.cat_key ,a.Cat_Desc ,a.line 
,a.FISCAL_YEAR ,a.FISCAL_WEEK ,coalesce(b.launch_date, c.launch_date) as launch_date
,coalesce(b.STORE_NUM_WITH_INVENTORY,0) as STORE_NUM_WITH_INVENTORY,coalesce(b.STORE_NUM_WITH_ONORDER,0) as STORE_NUM_WITH_ONORDER
,coalesce(b.GROSS_SALES_UNITS,0) as GROSS_SALES_UNITS,coalesce(b.NET_SALES_UNITS,0) as NET_SALES_UNITS
,coalesce(b.EOP_DC_Inventory_Units,0) as EOP_DC_Inventory_Units ,coalesce(b.EOP_DC_On_Order_Units,0) as EOP_DC_On_Order_Units
,coalesce(b.EOP_INVENTORY_UNITS,0) as EOP_INVENTORY_UNITS,coalesce(b.EOP_ON_ORDER_UNITS,0) as EOP_ON_ORDER_UNITS
,b.md_flag ,b.MD_TAKEN_flag ,c.md_max_date
,coalesce(b.First_wk_inv,c.First_wk_inv) as First_wk_inv
,sum(coalesce(b.net_SALES_UNITS,0)) over(partition by a.line 
order by cast(a.FISCAL_YEAR as int) ,cast(a.FISCAL_WEEK as int) rows unbounded preceding) as Cum_Sales
,case when coalesce(b.First_wk_inv,c.First_wk_inv) = 0 then 0 else (coalesce(b.net_SALES_UNITS,0)*1.0/coalesce(b.First_wk_inv,c.First_wk_inv)) end as Check_out_rate
,case when coalesce(b.First_wk_inv,c.First_wk_inv) = 0 then 0.0 else ((sum(coalesce(b.net_SALES_UNITS,0)) over(partition by a.line 
order by cast(a.FISCAL_YEAR as int) ,cast(a.FISCAL_WEEK as int) rows unbounded preceding))*1.0/coalesce(b.First_wk_inv,c.First_wk_inv)) end as Cum_STR
,(cast(a.FISCAL_YEAR as int)-cast(coalesce(b.launch_date, c.launch_date) as int)/100)*52 + (cast(a.FISCAL_WEEK as int)-cast(coalesce(b.launch_date, c.launch_date) as int)%100) + 1 as Age_in_weeks
into PLC_AD
from all_wk_line_base a
left join Inv_and_metrics_table b
on a.Line=b.Line 
and a.FISCAL_YEAR=b.FISCAL_YEAR and a.FISCAL_WEEK=b.FISCAL_WEEK
left join 
(
select a.*,b.md_max_date from (select distinct dept_key ,dept_desc ,cat_key ,Cat_Desc ,line ,launch_date ,First_wk_inv 
from Inv_and_metrics_table where 1=1 ) a
join 
(select distinct a.line ,a.md_max_date ,b.date_cnt from Inv_and_metrics_table a join
(select line ,count(distinct MD_FLag) as date_cnt from Inv_and_metrics_table group by line) b
on a.Line=b.Line
where 1=1 --and a.line=1776403
and case when date_cnt >0 and md_flag in ('First', 'Further') then 1
when date_cnt = 0 and md_flag is null then 1 else 0 end >0) b
on a.line=b.line
) c
on a.Line=c.Line 
where (cast(a.FISCAL_YEAR as int)*100 + cast(a.FISCAL_WEEK as int)) >= cast(coalesce(b.launch_date, c.launch_date)as int) 
and (cast(a.FISCAL_YEAR as int)*100 + cast(a.FISCAL_WEEK as int)) <= cast(c.md_max_date as int) 
--) a
--where line=1442235
;





--## PLC AD at catg. level
drop table if exists PLC_AD_Cat_level;
select a.dept_key ,a.dept_desc ,a.cat_key ,a.Cat_Desc ,Age_in_weeks
,sum(NET_SALES_UNITS) as NET_SALES_UNITS
,sum(Cum_sales) as Cum_sales
,sum(sum(NET_SALES_UNITS)) over(partition by cat_key order by Age_in_weeks rows unbounded preceding) as calc_cum_sales
,sum(first_wk_inv) as first_wk_inv 
,max(sum(first_wk_inv)) over(partition by cat_key) as max_inv
,case when max(sum(first_wk_inv)) over(partition by cat_key)=0 then 0 else sum(NET_SALES_UNITS)*1.0/max(sum(first_wk_inv)) over(partition by cat_key) end as Check_out_rate
,case when max(sum(first_wk_inv)) over(partition by cat_key)=0 then 0 else sum(sum(NET_SALES_UNITS)) over(partition by cat_key order by Age_in_weeks rows unbounded preceding)*1.0/max(sum(first_wk_inv)) over(partition by cat_key) end as CST
 into PLC_AD_Cat_level
 from PLC_AD a
 group by a.dept_key ,a.dept_desc ,a.cat_key ,a.Cat_Desc ,Age_in_weeks



--## Adding PLC results to PLC AD


select  a.* 
,b.phi1 ,b.phi2 ,b.phi3 ,b.Infl1 ,b.Infl2
,case when b.Infl1 is null then 'NA' 
when a.Age_in_weeks <= b.Infl1 then 'Growth' 
when a.Age_in_weeks <= b.Infl2 then 'Maturity' else 'Decliine' end as PLC_Stage
from PLC_AD a
left join PLC_Cat_Results b
on a.cat_key=b.Cat_key



--## Exploring PLC AD

select * from PLC_AD_Cat_level where cat_key=14163

select count(*) from PLC_AD

select cat_key ,Cat_Desc ,count(distinct line) from PLC_AD group by cat_key ,Cat_Desc order by count(distinct line) 

select * from PLC_AD where cat_key=14163

select top 100 * from PLC_AD 
where launch_date is null

select * from PLC_AD 
where line=1750517
order by FISCAL_YEAR ,FISCAL_WEEK
--1750024
