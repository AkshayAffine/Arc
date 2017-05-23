Use TPC_Arcadia;

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

--Merging Final AD with All wks table
drop table if exists RR_error_AD_All_wks;
select a.dept_key ,a.dept_desc ,a.cat_key ,a.Cat_Desc ,a.line 
,a.FISCAL_YEAR ,a.FISCAL_WEEK 
,coalesce(b.GROSS_SALES_UNITS,0) as GROSS_SALES_UNITS
,coalesce(b.NET_SALES_UNITS,0) as NET_SALES_UNITS
,case when coalesce(b.launch_date, c.launch_date) =0 then 999999 else coalesce(b.launch_date, c.launch_date) end as launch_date
into RR_error_AD_All_wks
from all_wk_line_base a
left join Final_master_AD_2 b
on a.Line=b.Line and a.FISCAL_YEAR=b.FISCAL_YEAR and a.FISCAL_WEEK=b.FISCAL_WEEK
left join (select line, min(cast(launch_date as int)) as launch_date from Final_master_AD_2 group by line) c
on a.Line=c.Line 
--where (cast(a.FISCAL_YEAR as int)*100 + cast(a.FISCAL_WEEK as int)) >= cast(coalesce(b.launch_date, c.launch_date)as int) 


select line, count(*) from 
(select line, min(cast(launch_date as int)) asd from Final_master_AD_2 group by line) c
group by line having count(*)>1

select top 10 * from Final_master_AD_2


select Cat_key, FISCAL_YEAR ,FISCAL_WEEK ,SUM(gross_sales_units) from Final_master_AD_2
where 1=1
and cat_key=10408
group by cat_key ,FISCAL_YEAR ,FISCAL_WEEK
order by FISCAL_YEAR ,FISCAL_WEEK


select distinct cat_key,line, launch_date ,case when coalesce(launch_date,999999)=0 then 999999 else launch_date end 
from Final_master_AD_2 
where cat_key=14422 


select cat_key ,min(cast(case when coalesce(launch_date,999999)=0 then 999999 else launch_date end as int)) as min_LD
from Final_master_AD_2 group by Cat_key


select top 100 * from RR_error_AD_All_wks

select top 100 * from RR_error_AD_All_wks where cat_key=14422

select top 100 * from RETURN_RATE_15_weeks;

select * from RETURN_RATE_15_weeks where cat_key=14422 order by FISCAL_YEAR, FISCAL_WEEK;


--Calculating RR using MA method and predicting for wk 137
drop table if exists RR_error_AD_All_wks_MA;
SELECT *
,case when CAST(b.GROSS_SALES as int)=0 then 0 else (CAST(b.RETURN_UNITS as int)*1.0/CAST(b.GROSS_SALES as int)) end AS Wkly_RR
,case when sum(GROSS_SALES) over(partition by dept_desc ,cat_key ,cat_desc  order by fiscal_year ,fiscal_week
                      rows between 13 preceding and 1 preceding) =0 then 0 
else sum(RETURN_UNITS) over(partition by dept_desc ,cat_key ,cat_desc  order by fiscal_year ,fiscal_week
                      rows between 13 preceding and 1 preceding) *1.0/
sum(GROSS_SALES) over(partition by dept_desc ,cat_key ,cat_desc  order by fiscal_year ,fiscal_week
                      rows between 13 preceding and 1 preceding) 
end as ma_13_wk_RR
,case when sum(GROSS_SALES) over(partition by dept_desc ,cat_key ,cat_desc  order by fiscal_year ,fiscal_week
                      rows between 12 preceding and current row) =0 then 0 
else sum(RETURN_UNITS) over(partition by dept_desc ,cat_key ,cat_desc  order by fiscal_year ,fiscal_week
                      rows between 12 preceding and current row) *1.0 /
sum(GROSS_SALES) over(partition by dept_desc ,cat_key ,cat_desc  order by fiscal_year ,fiscal_week
                      rows between 12 preceding and current row) 
end as pred_RR
INTO RR_error_AD_All_wks_MA
FROM
(
SELECT Dept_desc ,cat_key ,cat_desc  ,FISCAL_YEAR ,FISCAL_WEEK
--,min(cast(launch_date as int)) as launch_date
,sum(gross_sales_units) as GROSS_SALES
,(sum(gross_sales_units)-sum(net_sales_units)) AS RETURN_UNITS
--,sum(gross_sales_units) over(partition by dept_desc ,cat_key ,cat_desc order by fiscal_year,fiscal_week
--	rows between 3 preceding and current row) /4
--as Four_wk_avg_sales
FROM
RR_error_AD_All_wks a
--where FISCAL_YEAR =2016 
GROUP BY Dept_desc ,cat_key ,cat_desc ,FISCAL_YEAR ,FISCAL_WEEK
)b
join 
(select cat_key as key_cat ,min(cast(case when coalesce(launch_date,999999)=0 then 999999 else launch_date end as int)) as min_LD
from Final_master_AD_2 group by Cat_key
) c
on b.cat_key=c.key_cat
where 1=1
and (cast(b.FISCAL_YEAR as int)*100 + cast(b.FISCAL_WEEK as int)) >= cast(c.min_LD as int) 

--and b.GROSS_SALES >0 
--and b.FISCAL_YEAR =2016 
--and FISCAL_WEEK between 17 and 32




--Last 10 weeks MAPE

select Dept_desc ,cat_desc ,cat_key 
,avg(case when Wkly_RR=0 then 0.0 else ABS(Wkly_RR-ma_13_wk_RR)*1.0/Wkly_RR end) from RR_error_AD_All_wks_MA 
where FISCAL_WEEK between 23 and 32 and FISCAL_YEAR=2016 
and gross_sales >0
--and cat_key=14422 
group by Dept_desc ,cat_desc ,cat_key 


--Last week MAPE

select Dept_desc ,cat_desc ,cat_key 
,avg(case when Wkly_RR=0 then 0.0 else ABS(Wkly_RR-ma_13_wk_RR)*1.0/Wkly_RR end) from RR_error_AD_All_wks_MA 
where FISCAL_WEEK =32 and FISCAL_YEAR=2016 
and gross_sales >0
--and cat_key=14422 
group by Dept_desc ,cat_desc ,cat_key 


-- Predicted RR for Week 137
select Dept_desc ,cat_desc ,cat_key ,pred_RR  
from RR_error_AD_All_wks_MA 
where FISCAL_WEEK =32 and FISCAL_YEAR=2016 
and cat_key=14422

select * 
from RR_error_AD_All_wks_MA 
where  cat_key=14422


-- All cats and wks

select Dept_desc ,cat_desc ,cat_key ,min_ld ,FISCAL_YEAR ,FISCAL_WEEK ,Wkly_RR ,ma_13_wk_RR 
from RR_error_AD_All_wks_MA
where 1=1
--and cat_key=14422 
order by cat_key ,FISCAL_YEAR ,FISCAL_WEEK

select Dept_desc ,cat_desc ,cat_key ,min_ld ,FISCAL_YEAR ,FISCAL_WEEK ,GROSS_SALES,Wkly_RR ,ma_13_wk_RR 
from RR_error_AD_All_wks_MA
where 1=1
and FISCAL_WEEK =32 and FISCAL_YEAR=2016 
--and cat_key=14422 
order by cat_key ,FISCAL_YEAR ,FISCAL_WEEK










select cat_desc ,cat_key ,count(*) as cnt_wks from RETURN_RATE_15_weeks group by cat_desc ,cat_key 
having count(*) <16

select cat_desc ,cat_key ,count(*) as cnt_wks from RR_error_AD_All_wks_MA group by cat_desc ,cat_key 
having count(*) <32

select * from RR_error_AD_All_wks_MA 
where cat_key=14422 order by FISCAL_YEAR ,FISCAL_WEEK


select *
,((cast(RETURN_RATE as float)-(cast(pred_ma_13 as float)))/nullif(cast(RETURN_RATE as float),0))*100 as perc_rr
from 
(
select *,
avg(return_rate) over(partition by dept_desc,cat_key,cat_desc,fiscal_year order by fiscal_week
                      rows between 13 preceding and 1 preceding) as pred_ma_13
 from RETURN_RATE_15_weeks
 ) a
 where fiscal_week in (31,32)




select *,
sum(RETURN_UNITS) over(partition by dept_desc ,cat_key ,cat_desc ,fiscal_year order by fiscal_week
                      rows between 13 preceding and 1 preceding) *1.0/
sum(GROSS_SALES) over(partition by dept_desc ,cat_key ,cat_desc ,fiscal_year order by fiscal_week
                      rows between 13 preceding and 1 preceding) 
as pred_ma_13
,sum(RETURN_UNITS) over(partition by dept_desc ,cat_key ,cat_desc ,fiscal_year order by fiscal_week
                      rows between 12 preceding and current row) *1.0 /
sum(GROSS_SALES) over(partition by dept_desc ,cat_key ,cat_desc ,fiscal_year order by fiscal_week
                      rows between 12 preceding and current row) 
as pred_137_wk
from RETURN_RATE_15_weeks
where cat_key=14422 order by FISCAL_YEAR ,FISCAL_WEEK



