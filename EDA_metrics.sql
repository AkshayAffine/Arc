
-----------------=============================== At Overall Level ====================================-------------------------------
Drop table EDA_metrics;

select a.*,[Average Temp (°C)],[Rain],[GDP (In Millions)],[% Change in inflation],[Weekly earnings whole industry in pounds]
	,[Weekly earnings Retail industry in pounds]
	,[National Events] as National_Events
	,[Public Holidays] as Public_Holidays
into EDA_Metrics
from
	(SELECT B.FISCAL_YEAR,B.FISCAL_WEEK,
		SUM(B.GROSS_SALES_UNITS) AS SALES,
		SUM(B.GROSS_SALES_DOLLARS) AS REVENUE, 
		SUM(B.UNIT_COST*B.GROSS_SALES_UNITS)*1.0/SUM(B.GROSS_SALES_UNITS) AS UNIT_COST_WEIGHT,
		SUM(B.CURRENT_RETAIL*B.GROSS_SALES_UNITS)*1.0/SUM(B.GROSS_SALES_UNITS) AS CURRENT_RETAIL_WEIGHT,
		SUM(B.FULL_PRICE*B.GROSS_SALES_UNITS)*1.0/SUM(B.GROSS_SALES_UNITS) AS FULL_PRICE_WEIGHT,
		SUM(B.FINAL_PRICE*B.GROSS_SALES_UNITS)*1.0/SUM(B.GROSS_SALES_UNITS) AS FINAL_PRICE_WEIGHT,
		SUM(B.md_price*B.GROSS_SALES_UNITS)*1.0/SUM(B.GROSS_SALES_UNITS) AS MD_PRICE_WEIGHT,
		SUM(B.PROMO_PRICE*B.GROSS_SALES_UNITS)*1.0/SUM(B.GROSS_SALES_UNITS) AS PROMO_PRICE_WEIGHT,
		SUM(B.PRICE_POINT*B.GROSS_SALES_UNITS)*1.0/SUM(B.GROSS_SALES_UNITS) AS PRICE_POINT_WEIGHT,
		SUM(B.GROSS_SALES_UNITS-B.NET_SALES_UNITS) AS RETURNS_1,
		SUM(B.MARK_UP*B.GROSS_SALES_UNITS)*1.0/SUM(B.GROSS_SALES_UNITS) AS MARK_UP_WEIGHT,
		SUM(B.NEW_LOWER_PRICE*B.GROSS_SALES_UNITS)*1.0/SUM(B.GROSS_SALES_UNITS) AS NEW_LOWER_PRICE_WEIGHT,
		count(distinct (case when GROSS_SALES_UNITS>0 then MERCHANDISE_KEY end)) AS DISTINCT_PRODUCTS_SOLD,
		((SUM(case when promo_price is not null then B.MD_PRICE*B.GROSS_SALES_UNITS end)*1.0/SUM(B.GROSS_SALES_UNITS))-(SUM(B.PROMO_PRICE*B.GROSS_SALES_UNITS)*1.0/SUM(B.GROSS_SALES_UNITS)))*100.0/
		(SUM(case when promo_price is not null then B.MD_PRICE*B.GROSS_SALES_UNITS end)*1.0/SUM(B.GROSS_SALES_UNITS)) promo_discount,
		((SUM(case when price_point is not null then B.Regular_Price*B.GROSS_SALES_UNITS end)*1.0/SUM(B.GROSS_SALES_UNITS))-(SUM(B.PRICE_Point*B.GROSS_SALES_UNITS)*1.0/SUM(B.GROSS_SALES_UNITS)))*100.0/
		(SUM(case when price_point is not null then B.Regular_Price*B.GROSS_SALES_UNITS end)*1.0/SUM(B.GROSS_SALES_UNITS)) md_discount
	FROM
	(      
	   SELECT A.*,
	   CASE WHEN A.PRICE_POINT IS NULL AND A.FULL_PRICE<A.CURRENT_RETAIL THEN CURRENT_RETAIL-FULL_PRICE END AS MARK_UP,
	   CASE WHEN A.PRICE_POINT IS NULL AND A.FULL_PRICE>A.CURRENT_RETAIL THEN FULL_PRICE-CURRENT_RETAIL END AS NEW_LOWER_PRICE
	   FROM 
	   (
		  SELECT MERCHANDISE_KEY,
		  cat_desc,
		  dept_desc,
		  line_key,
		  FISCAL_YEAR,
		  FISCAL_WEEK,
		  CAST(GROSS_SALES_UNITS AS DECIMAL(38,5)) AS GROSS_SALES_UNITS,
		  CAST(GROSS_SALES_DOLLARS AS DECIMAL(38,5)) AS GROSS_SALES_DOLLARS,
		  CAST(NET_SALES_DOLLARS AS DECIMAL(38,5)) AS NET_SALES_DOLLARS,
		  CAST(NET_SALES_UNITS AS DECIMAL(38,5)) AS NET_SALES_UNITS,
		  CAST(CURRENT_RETAIL AS DECIMAL(38,5)) AS CURRENT_RETAIL,
		  CAST(UNIT_COST AS DECIMAL(38,5)) AS UNIT_COST,
		  CAST(FULL_PRICE AS DECIMAL(38,5)) AS FULL_PRICE,
		  CAST(Final_Price AS DECIMAL(38,5)) AS Final_Price,
		  CAST(PROMO_PRICE AS DECIMAL(38,5)) AS PROMO_PRICE,
		  CAST(PRICE_POINT AS DECIMAL(38,5)) AS PRICE_POINT,
		  CAST(MD_PRICE AS DECIMAL(38,5)) AS MD_PRICE,
		  CAST(Regular_Price as DECIMAL(38,5)) AS Regular_Price
		  FROM [dbo].[FINAL_MASTER_AD_1]
		  WHERE MERCHANDISE_KEY IS NOT NULL
	   )A     
	)B
	GROUP BY B.FISCAL_YEAR,B.FISCAL_WEEK
	)a
left join [Macro_level_data_weekly_level] b
on a.FISCAL_YEAR=b.FISCAL_YEAR and a.FISCAL_WEEK=b.FISCAL_WEEK
left join Holidays c
on a.FISCAL_YEAR=c.FISCAL_YEAR and a.FISCAL_WEEK=c.FISCAL_WEEK
ORDER BY a.FISCAL_YEAR,a.FISCAL_WEEK




-----------Transposing data for EDA Excel
select fiscal_year,fiscal_week,measure,measure_value
from eda_metrics a
unpivot
(measure_value for measure in 
	(SALES,
REVENUE,
UNIT_COST_WEIGHT,
CURRENT_RETAIL_WEIGHT,
FULL_PRICE_WEIGHT,
FINAL_PRICE_WEIGHT,
PROMO_PRICE_WEIGHT,
PRICE_POINT_WEIGHT,
RETURNS_1,
MARK_UP_WEIGHT,
NEW_LOWER_PRICE_WEIGHT,
DISTINCT_PRODUCTS_SOLD,
promo_discount,
md_discount,
[Average Temp (°C)],
[Rain],
[GDP (In Millions)],
[% Change in inflation],
[Weekly earnings whole industry in pounds],
[Weekly earnings Retail industry in pounds],
National_Events,
Public_Holidays
) )as unpvt





--------====================== At Dept level ===============--------------------------------------
Drop table EDA_Metrics_dept;

select a.*,[Average Temp (°C)],[Rain],[GDP (In Millions)],[% Change in inflation],[Weekly earnings whole industry in pounds]
	,[Weekly earnings Retail industry in pounds]
into EDA_Metrics_dept
from
	(SELECT B.FISCAL_YEAR,B.FISCAL_WEEK,dept_desc,
		SUM(B.GROSS_SALES_UNITS) AS SALES,
		SUM(B.GROSS_SALES_DOLLARS) AS REVENUE, 
		SUM(B.UNIT_COST*B.GROSS_SALES_UNITS)*1.0/(case when SUM(B.GROSS_SALES_UNITS)=0 then 1 else SUM(B.GROSS_SALES_UNITS) end)  AS UNIT_COST_WEIGHT,
		SUM(B.CURRENT_RETAIL*B.GROSS_SALES_UNITS)*1.0/(case when SUM(B.GROSS_SALES_UNITS)=0 then 1 else SUM(B.GROSS_SALES_UNITS) end) AS CURRENT_RETAIL_WEIGHT,
		SUM(B.FULL_PRICE*B.GROSS_SALES_UNITS)*1.0/(case when SUM(B.GROSS_SALES_UNITS)=0 then 1 else SUM(B.GROSS_SALES_UNITS) end) AS FULL_PRICE_WEIGHT,
		SUM(B.Final_Price*B.GROSS_SALES_UNITS)*1.0/(case when SUM(B.GROSS_SALES_UNITS)=0 then 1 else SUM(B.GROSS_SALES_UNITS) end) AS FINAL_PRICE_WEIGHT,
		SUM(B.md_price*B.GROSS_SALES_UNITS)*1.0/(case when SUM(B.GROSS_SALES_UNITS)=0 then 1 else SUM(B.GROSS_SALES_UNITS) end) AS MD_PRICE_WEIGHT,
		SUM(B.PROMO_PRICE*B.GROSS_SALES_UNITS)*1.0/(case when SUM(B.GROSS_SALES_UNITS)=0 then 1 else SUM(B.GROSS_SALES_UNITS) end) AS PROMO_PRICE_WEIGHT,
		SUM(B.PRICE_POINT*B.GROSS_SALES_UNITS)*1.0/(case when SUM(B.GROSS_SALES_UNITS)=0 then 1 else SUM(B.GROSS_SALES_UNITS) end) AS PRICE_POINT_WEIGHT,
		SUM(B.GROSS_SALES_UNITS-B.NET_SALES_UNITS) AS RETURNS_1,
		SUM(B.MARK_UP*B.GROSS_SALES_UNITS)*1.0/(case when SUM(B.GROSS_SALES_UNITS)=0 then 1 else SUM(B.GROSS_SALES_UNITS) end) AS MARK_UP_WEIGHT,
		SUM(B.NEW_LOWER_PRICE*B.GROSS_SALES_UNITS)*1.0/(case when SUM(B.GROSS_SALES_UNITS)=0 then 1 else SUM(B.GROSS_SALES_UNITS) end) AS NEW_LOWER_PRICE_WEIGHT,
		count(distinct (case when GROSS_SALES_UNITS>0 then MERCHANDISE_KEY end)) AS DISTINCT_PRODUCTS_SOLD,
		((SUM(case when promo_price is not null then B.MD_PRICE*B.GROSS_SALES_UNITS end)*1.0/(case when SUM(B.GROSS_SALES_UNITS)=0 then 1 else SUM(B.GROSS_SALES_UNITS) end))
			-(SUM(B.PROMO_PRICE*B.GROSS_SALES_UNITS)*1.0/(case when SUM(B.GROSS_SALES_UNITS)=0 then 1 else SUM(B.GROSS_SALES_UNITS) end)))*100.0/
		(case when (SUM(case when promo_price is not null then B.MD_PRICE*B.GROSS_SALES_UNITS end)*1.0/SUM(B.GROSS_SALES_UNITS))=0 then 1
			else (SUM(case when promo_price is not null then B.MD_PRICE*B.GROSS_SALES_UNITS end)*1.0/SUM(B.GROSS_SALES_UNITS)) end) promo_discount,
		((SUM(case when price_point is not null then B.Regular_Price*B.GROSS_SALES_UNITS end)*1.0/(case when SUM(B.GROSS_SALES_UNITS)=0 then 1 else SUM(B.GROSS_SALES_UNITS) end))
			-(SUM(B.PRICE_Point*B.GROSS_SALES_UNITS)*1.0/(case when SUM(B.GROSS_SALES_UNITS)=0 then 1 else SUM(B.GROSS_SALES_UNITS) end)))*100.0/
		(case when (SUM(case when price_point is not null then B.Regular_Price*B.GROSS_SALES_UNITS end)*1.0/SUM(B.GROSS_SALES_UNITS))=0 then 1
			else (SUM(case when price_point is not null then B.Regular_Price*B.GROSS_SALES_UNITS end)*1.0/SUM(B.GROSS_SALES_UNITS)) end) md_discount
	FROM
	(      
	   SELECT A.*,
	   CASE WHEN A.PRICE_POINT IS NULL AND A.FULL_PRICE<A.CURRENT_RETAIL THEN CURRENT_RETAIL-FULL_PRICE END AS MARK_UP,
	   CASE WHEN A.PRICE_POINT IS NULL AND A.FULL_PRICE>A.CURRENT_RETAIL THEN FULL_PRICE-CURRENT_RETAIL END AS NEW_LOWER_PRICE
	   FROM 
	   (
		  SELECT MERCHANDISE_KEY,
		  cat_desc,
		  dept_desc,
		  line_key,
		  FISCAL_YEAR,
		  FISCAL_WEEK,
		  CAST(GROSS_SALES_UNITS AS DECIMAL(38,5)) AS GROSS_SALES_UNITS,
		  CAST(GROSS_SALES_DOLLARS AS DECIMAL(38,5)) AS GROSS_SALES_DOLLARS,
		  CAST(NET_SALES_DOLLARS AS DECIMAL(38,5)) AS NET_SALES_DOLLARS,
		  CAST(NET_SALES_UNITS AS DECIMAL(38,5)) AS NET_SALES_UNITS,
		  CAST(CURRENT_RETAIL AS DECIMAL(38,5)) AS CURRENT_RETAIL,
		  CAST(UNIT_COST AS DECIMAL(38,5)) AS UNIT_COST,
		  CAST(FULL_PRICE AS DECIMAL(38,5)) AS FULL_PRICE,
		  CAST(Final_Price AS DECIMAL(38,5)) AS Final_Price,
		  CAST(PROMO_PRICE AS DECIMAL(38,5)) AS PROMO_PRICE,
		  CAST(PRICE_POINT AS DECIMAL(38,5)) AS PRICE_POINT,
		  CAST(MD_PRICE AS DECIMAL(38,5)) AS MD_PRICE,
		  CAST(Regular_Price as DECIMAL(38,5)) AS Regular_Price
		  FROM [dbo].[FINAL_MASTER_AD_1]
		  WHERE MERCHANDISE_KEY IS NOT NULL
	   )A     
	)B
	GROUP BY B.FISCAL_YEAR,B.FISCAL_WEEK,dept_desc
	)a
left join [Macro_level_data_weekly_level] b
on a.FISCAL_YEAR=b.FISCAL_YEAR and a.FISCAL_WEEK=b.FISCAL_WEEK
ORDER BY a.FISCAL_YEAR,a.FISCAL_WEEK,dept_desc

--Transposing
select fiscal_year,fiscal_week,dept_desc,measure,measure_value
from EDA_Metrics_dept a
unpivot
(measure_value for measure in 
	(SALES,
REVENUE,
UNIT_COST_WEIGHT,
CURRENT_RETAIL_WEIGHT,
FULL_PRICE_WEIGHT,
Final_Price_Weight,
PROMO_PRICE_WEIGHT,
PRICE_POINT_WEIGHT,
RETURNS_1,
MARK_UP_WEIGHT,
NEW_LOWER_PRICE_WEIGHT,
DISTINCT_PRODUCTS_SOLD,
promo_discount,
md_discount,
[Average Temp (°C)],
[Rain],
[GDP (In Millions)],
[% Change in inflation],
[Weekly earnings whole industry in pounds],
[Weekly earnings Retail industry in pounds]
) )as unpvt