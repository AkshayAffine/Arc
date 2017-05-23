select cat_key,coalesce(infl1,dept_infl1) as infl1,coalesce(infl2,dept_infl2) as infl2  
into cat_age_interim_tab
from
	(
	select cat.*,dept.infl1 as dept_infl1,dept.infl2 as dept_infl2
	from 
		(
		select dept_key,dept_desc,avg(cast(infl1 as int)) as infl1,avg(cast(infl2 as int)) as infl2 from
			(
			select distinct b.cat_key,infl1,infl2,
			a.HIERARCHY3_DESC as dept_desc,a.HIERARCHY3_ID dept_key
			from [dbo].[mh] a
			join Category_Results b
			on b.cat_key=a.hierarchy4_id
			)a
		group by dept_key,dept_desc
		)dept
	right join 
	(
	select a.*,b.infl1,b.infl2 from 
			(
			select distinct a.all_categories as cat_key,b.HIERARCHY3_ID dept_key
			from all_cats a
			join [dbo].[mh] b
			on a.all_categories=b.hierarchy4_id
			)a
		left join category_results b
		on a.cat_key=b.cat_key

	)cat
	on dept.dept_key=cat.dept_key
	)
a

-----------------------------------



--------------product level table with all metrics--------

select top 10 * from Category_Results

drop table Regression_interim_product_level_21_cats

SELECT *,
CASE WHEN [age_weeks]<=INFL1 THEN 'G'
WHEN [age_weeks]>INFL1 AND [age_weeks]<=INFL2 THEN 'M'
WHEN [age_weeks]>INFL2 THEN 'D'
ELSE 'None'
end as Cycle_Type
into Regression_interim_product_level_21_cats
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

LEFT JOIN cat_age_interim_tab C
ON b.CAT_KEY=c.cat_key

)a
where Merchandise_key is not null



---rolled up table from above cluster nad stage level table---

drop table Regression_ad_cat_cluster_interim_21_cats

select * from Regression_ad_cat_cluster_interim

Select *,
case when (MD_DISCOUNT*1.0)>=60 then 1 else 0 end as Discount_Flag
into Regression_ad_cat_cluster_interim_21_cats
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
	from Regression_interim_product_level_21_cats
	group by cat_key,cluster_number,fiscal_year,FISCAL_WEEK
) A
left JOIN [dbo].[Holidays] B
ON A.Fiscal_year=B.Fiscal_Year
AND A.Fiscal_Week=B.Fiscal_Week
) a


-------------------------

------------------------data for type 2 regression-----------

Select *,
case when (MD_DISCOUNT*1.0)>=60 then 1 else 0 end as Discount_Flag
into Regression_final_ad_type_2_21_cats
from
(
SELECT A.*,
((Weighted_regular_Price-Weighted_final_Price)/NULLIF(Weighted_regular_Price,0))*100 AS MD_DISCOUNT,
(INVENTORY*1.0)/(NULLIF(GROSS_SALES_UNITS,0)*1.0) AS INVENTORY_RATIO,
(Decline*1.0)/(nullif((Decline+Growth+Maturity),0)*1.0) as decline_perc,
(Growth*1.0)/(nullif((Decline+Growth+Maturity),0)*1.0) as Growth_perc,
(Maturity*1.0)/(nullif((Decline+Growth+Maturity),0)*1.0) as Maturity_perc,
--(pos*1.0)/(nullif((pos+First_mk+further),0)*1.0) as pos_perc,
--(First_mk*1.0)/(nullif((pos+First_mk+further),0)*1.0) as First_perc,
--(further*1.0)/(nullif((pos+First_mk+further),0)*1.0) as further_perc,

b.[National Events],b.[Public Holidays]

FROM 
(
	select distinct cat_key,cluster_number,Disc_Type_Flag,fiscal_year,FISCAL_WEEK,
	sum(GROSS_SALES_UNITS) AS GROSS_SALES_UNITS,
	SUM((GROSS_SALES_UNITS*1.0)*(Regular_price*1.0))/NULLIF(sum(GROSS_SALES_UNITS),0) AS Weighted_regular_Price,
	SUM((GROSS_SALES_UNITS*1.0)*(Final_price*1.0))/NULLIF(sum(GROSS_SALES_UNITS),0) AS Weighted_final_Price,
	sum(EOP_DC_ON_ORDER_UNITS) EOP_DC_ON_ORDER_UNITS,
	SUM(INVENTORY) INVENTORY,
	AVG(AGE_WEEKS) AGE_WEEKS,
	count(case when Cycle_Type='D' then MERCHANDISE_KEY END) 'Decline',
	count(case when Cycle_Type='G' then MERCHANDISE_KEY END) 'Growth',
	count(case when Cycle_Type='M' then MERCHANDISE_KEY END) 'Maturity'
	---count(case when Disc_Type_Flag='POS' then MERCHANDISE_KEY end) 'pos',
	---count(case when Disc_Type_Flag='First' then MERCHANDISE_KEY end) 'First_mk',
	---count(case when Disc_Type_Flag='Further' then MERCHANDISE_KEY end) 'Further'
	from Regression_interim_product_level_21_cats
	group by cat_key,cluster_number,Disc_Type_Flag,fiscal_year,FISCAL_WEEK
) A
left JOIN [dbo].[Holidays] B
ON A.Fiscal_year=B.Fiscal_Year
AND A.Fiscal_Week=B.Fiscal_Week
) a


