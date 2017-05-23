select top 10000 * from [dbo].[final_master_AD_2]

select * from [dbo].[Cluster_Cat_mapping]


--------------------table with cluster number and stage of the product--------------

select * from temp_sales_cat_level

drop table Ad_cluster_number

select top 10000 * from [dbo].[Final_master_AD_2]

Select a.*,
case when md_taken_flag is null and pos_flag_lead is not null then 'POS'
WHEN MD_FLag='First' then 'First'
when MD_FLag='Further' then 'Further'
else 'None'
end as Disc_Type_Flag
,b.cluster_number
into Ad_cluster_number
from
(
select a.*,b.LINK_LINE,c.stage
from (select *,LEAD(md_taken_flag,2) 
		over(partition by merchandise_key order by fiscal_year,fiscal_week) as pos_flag_lead
		from
		[dbo].[Final_master_AD_2]) a
left join 
	(select merchandise_key,location_key, 
	case when attribute1='NULL' or attribute1 = '' then MERCHANDISE_KEY
	ELSE attribute1
	END AS LINK_LINE 
	FROM ITEMS_CDA 
	WHERE LOCATION_KEY = 'AA') b
on a.MERCHANDISE_KEY=b.MERCHANDISE_KEY

left join [dbo].[product_current_stage] c
on a.MERCHANDISE_KEY=c.MERCHANDISE_KEY

)a

left join [dbo].[Cluster_Cat_mapping] b
on a.Cat_key=b.Cat_key
and a.Link_line=b.link_line

where MERCHANDISE_KEY is not null


select top 10 * from Ad_cluster_number
where merchandise_key=1584414

select cat_key,count(distinct link_line),count(distinct cluster_number) from Ad_cluster_number
group by cat_key
order by count(distinct link_line)

select *,count(link_line) over(partition by cat_key) as no_of_pdts
from Ad_cluster_number


-----2307045


-------------------------calendar fro age----------
select*,rank() over(order by year_week) as overall_rank 
into Cal_year_week
from
(
select *,concat(fiscal_year,(case when len(fiscal_week)<2 then concat(0,fiscal_week) else fiscal_week end)) Year_week
from cal
)a
--------------------------merchandise week level age table------

drop table merchadise_age_table

select a.*,b.overall_rank as Week_rank,SUBSTRING(b.year_week,1,4) as Fiscal_year,
cast((case when SUBSTRING(b.year_week,5,1)=0 then sUBSTRING(b.year_week,6,1) else sUBSTRING(b.year_week,5,2) end) as int) as Fiscal_week
,(b.overall_rank-a.overall_rank+1) age_weeks
into merchadise_age_table
from 
	(
	select a.*,b.overall_rank
	from 
		(
			select distinct merchandise_key,cat_key,final_launch_date
			from [dbo].[Master_AD_plc4]
			--order by merchandise_key,cat_key
		) a
		join Cal_year_week b
		on a.final_launch_date=b.Year_week
	) a
join (Select * from Cal_year_week where overall_rank<=136) b
on b.overall_rank>=a.overall_rank
order by fiscal_year,fiscal_week

--------------product level table with all metrics--------

select top 10 * from Category_Results

drop table Regression_interim_product_level

SELECT *,
CASE WHEN [age_weeks]<=INFL1 THEN 'G'
WHEN [age_weeks]>INFL1 AND [age_weeks]<=INFL2 THEN 'M'
WHEN [age_weeks]>INFL2 THEN 'D'
ELSE 'None'
end as Cycle_Type
into Regression_interim_product_level
FROM 
(
select a.[merchandise_key],a.[cat_key],a.[Fiscal_year],a.[Fiscal_week],a.[age_weeks],
b.[GROSS_SALES_UNITS],b.[Regular_price],b.[Final_price],b.[EOP_DC_On_Order_Units],b.[inventory],b.[LINK_LINE],b.[cluster_number],
b.Disc_Type_Flag,
C.INFL1,C.INFL2

from Ad_cluster_number b
left join merchadise_age_table a
on a.Merchandise_key=b.MERCHANDISE_KEY
and a.cat_key=b.cat_key
and a.fiscal_year=b.fiscal_year
and a.fiscal_week=b.fiscal_week

LEFT JOIN Category_Results C
ON b.CAT_KEY=c.cat_key

)a
where Merchandise_key is not null

select distinct cat_key,cluster_number from Regression_interim_product_level
order by cat_key


---rolled up table from above cluster nad stage level table---

drop table Regression_ad_cat_cluster_interim

select * from Regression_ad_cat_cluster_interim

Select *,
case when (MD_DISCOUNT*1.0)>=60 then 1 else 0 end as Discount_Flag
into Regression_ad_cat_cluster_interim
from
(
SELECT A.*,
((Weighted_regular_Price-Weighted_final_Price)/NULLIF(Weighted_regular_Price,0))*100 AS MD_DISCOUNT,
(INVENTORY*1.0)/(NULLIF(GROSS_SALES_UNITS,0)*1.0) AS INVENTORY_RATIO,
(Decline*1.0)/(nullif((Decline+Growth+Maturity),0)*1.0) as decline_perc,
(Growth*1.0)/(nullif((Decline+Growth+Maturity),0)*1.0) as Growth_perc,
(Maturity*1.0)/(nullif((Decline+Growth+Maturity),0)*1.0) as Maturity_perc,
(pos*1.0)/(nullif((pos+First_mk+further),0)*1.0) as pos_perc,
(First_mk*1.0)/(nullif((pos+First_mk+further),0)*1.0) as First_perc,
(further*1.0)/(nullif((pos+First_mk+further),0)*1.0) as further_perc,

b.[National Events],b.[Public Holidays]

FROM 
(
	select distinct cat_key,cluster_number,fiscal_year,FISCAL_WEEK,
	sum(GROSS_SALES_UNITS) AS GROSS_SALES_UNITS,
	SUM((GROSS_SALES_UNITS*1.0)*(Regular_price*1.0))/NULLIF(sum(GROSS_SALES_UNITS),0) AS Weighted_regular_Price,
	SUM((GROSS_SALES_UNITS*1.0)*(Final_price*1.0))/NULLIF(sum(GROSS_SALES_UNITS),0) AS Weighted_final_Price,
	sum(EOP_DC_ON_ORDER_UNITS) EOP_DC_ON_ORDER_UNITS,
	SUM(INVENTORY) INVENTORY,
	AVG(AGE_WEEKS) AGE_WEEKS,
	count(case when Cycle_Type='D' then MERCHANDISE_KEY END) 'Decline',
	count(case when Cycle_Type='G' then MERCHANDISE_KEY END) 'Growth',
	count(case when Cycle_Type='M' then MERCHANDISE_KEY END) 'Maturity',
	count(case when Disc_Type_Flag='POS' then MERCHANDISE_KEY end) 'pos',
	count(case when Disc_Type_Flag='First' then MERCHANDISE_KEY end) 'First_mk',
	count(case when Disc_Type_Flag='Further' then MERCHANDISE_KEY end) 'Further'
	from Regression_interim_product_level
	group by cat_key,cluster_number,fiscal_year,FISCAL_WEEK
) A
left JOIN [dbo].[Holidays] B
ON A.Fiscal_year=B.Fiscal_Year
AND A.Fiscal_Week=B.Fiscal_Week
) a


select distinct cat_key,cluster_number from Regression_ad_cat_cluster_interim
order by cat_key,cluster_number

select * from Regression_ad_cat_cluster_interim
order by cat_key,cluster_number,fiscal_year,Fiscal_week

select top 10 * from [dbo].[Category_Results]

