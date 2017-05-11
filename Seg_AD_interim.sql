select 
E.Cat_key,
E.LINK_LINE,
DENSE_RANK() OVER (ORDER BY E.Cat_key) AS Rank,
SUM(E.sales) SALES,
AVG(E.price) price,
AVG(E.checkout_rate) checkout_rate,
AVG(E.age_weeks) age_weeks
from
(
select C.*,D.LINK_LINE
from
(
select B.Cat_key,
B.MERCHANDISE_KEY,
Sum(B.GROSS_SALES_UNITS) as sales,
AVG(B.Regular_price) as price,
AVG(B.checkout) as checkout_rate,
(((2016-max(B.LAUNCH_YEAR))*52)+(37-max(B.LAUNCH_WEEK))) as age_weeks
from
		(
		select A.FISCAL_YEAR,A.FISCAL_WEEK,A.Cat_key,A.MERCHANDISE_KEY, 
		A.gross_sales_units,
		A.Regular_price,
		LEFT(A.launch_date,4) AS LAUNCH_YEAR,RIGHT(A.launch_date,2) AS LAUNCH_WEEK,
		FIRST_VALUE(coalesce(A.inventory,0)+coalesce(A.NET_SALES_UNITS,0)) over(partition by merchandise_key order by fiscal_year ,fiscal_week) as first_week_inv,
		inventory,
		(gross_sales_units*1.0/A.total_inv) as checkout
		from
			(
			select *,inventory+NET_SALES_UNITS as total_inv
			from [dbo].[final_master_AD_2]
			where MERCHANDISE_KEY is not null
			)A
		WHERE A.total_inv <> 0
		)B
group by B.Cat_key,B.MERCHANDISE_KEY
having (((2016-max(B.LAUNCH_YEAR))*52)+(37-max(B.LAUNCH_WEEK))) >0
)C
join
(select merchandise_key,location_key, 
case when attribute1='NULL' or attribute1 = '' then MERCHANDISE_KEY
ELSE attribute1
END AS LINK_LINE 
FROM ITEMS_CDA 
WHERE LOCATION_KEY = 'AA'
)D
ON C.MERCHANDISE_KEY= D.MERCHANDISE_KEY
)E
GROUP BY E.Cat_key,E.LINK_LINE
ORDER BY E.Cat_key,E.LINK_LINE
