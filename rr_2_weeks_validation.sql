SELECT *,
((CAST(b.RETURN_UNITS as int)*1.0/CAST(b.GROSS_SALES as int)*1.0)*1.0) AS RETURN_RATE
INTO RETURN_RATE_15_weeks
FROM
(
SELECT Dept_desc ,cat_key ,cat_desc,FISCAL_YEAR,FISCAL_WEEK,
sum(gross_sales_units) as GROSS_SALES,
(sum(gross_sales_units)-sum(net_sales_units)) AS RETURN_UNITS
FROM
(
select * 
from
[dbo].[Final_master_AD_2]
where merchandise_key is not null
)a
GROUP BY Dept_desc ,cat_key ,cat_desc,FISCAL_YEAR,FISCAL_WEEK
)b
where b.GROSS_SALES >0 and b.FISCAL_YEAR =2016 and FISCAL_WEEK between 17 and 32




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

