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

left join [dbo].[Cluster_Cat_mapping] b --------------------change this with the new table name---
on a.Cat_key=b.Cat_key
and a.Link_line=b.link_line

where MERCHANDISE_KEY is not null



-----2307045


-------------------------calendar fro age----------
select*,rank() over(order by year_week) as overall_rank 
into Cal_year_week
from
(
select *,concat(fiscal_year,(case when len(fiscal_week)<2 then concat(0,fiscal_week) else fiscal_week end)) Year_week
from cal
)a

select * from Cal_year_week 
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

select top 10 * from merchadise_age_table where age_weeks<0
----------------------------------------
---------------------taking depts infl's to cats-----

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


--------------product level table with all metrics--------

select top 10 * from Category_Results

select top 10 * from Ad_cluster_number

drop table Regression_interim_product_level



	SELECT *,
	CASE WHEN [age_weeks]<=INFL1 THEN 'G'
	WHEN [age_weeks]>INFL1 AND [age_weeks]<=INFL2 THEN 'M'
	WHEN [age_weeks]>INFL2 THEN 'D'
	ELSE 'None'
	end as Cycle_Type
	into Regression_product_level
	FROM 
	(
	select b.Dept_Desc,b.Dept_key,a.[merchandise_key],a.[cat_key],b.Cat_Desc,a.[Fiscal_year],a.[Fiscal_week],a.[age_weeks],
	b.[GROSS_SALES_UNITS],b.[Regular_price],b.[Final_price],b.[EOP_DC_On_Order_Units],b.[inventory],b.[LINK_LINE],b.[cluster_number],
	b.Disc_Type_Flag,
	C.INFL1,C.INFL2
	from Ad_cluster_number b
	left join merchadise_age_table a
	on a.Merchandise_key=b.MERCHANDISE_KEY
	and a.cat_key=b.cat_key
	and a.fiscal_year=b.fiscal_year
	and a.fiscal_week=b.fiscal_week

	LEFT JOIN cat_age_interim_tab C -----------------------chnaged table name for categiroes
	ON b.CAT_KEY=c.cat_key

	)a
	where Merchandise_key is not null

select count(distinct cat_key) from Category_Results --454
select count(distinct cat_key) from Regression_interim_product_level where Cycle_Type ='None' --21
select top 10 * from Regression_interim_product_level



---rolled up table from above cluster nad stage level table---

drop table Regression_ad_type_1

drop table Regression_ad_type_1_interim

select * from Regression_ad_type_1
where Weighted_final_Price is null

--select * from Regression_ad_cat_cluster_interim_key

Select *,
lag(INVENTORY_RATIO,1,0) over(partition by Dept_Desc,cluster_key order by a.fiscal_year,a.fiscal_week) as inventory_ratio_lag,
lag(INVENTORY,1,0) over(partition by Dept_Desc,cluster_key order by a.fiscal_year,a.fiscal_week) as inventory_lag
,rank() over(partition by Dept_Desc,cluster_key order by a.fiscal_year,a.fiscal_week) as Weeks_since_Launch
---,case when (MD_DISCOUNT*1.0)>=40 then 1 else 0 end as High_Discount_Flag
,case when [National Events]>[Public Holidays] then [National Events]
else [Public Holidays]
end as holiday_flag
into Regression_ad_type_1_interim
from
(
SELECT A.*,
((Weighted_regular_Price-Weighted_final_Price)/NULLIF(Weighted_regular_Price,0))*100 AS MD_DISCOUNT,

(INVENTORY*1.0)/(NULLIF(GROSS_SALES_UNITS,0)*1.0) AS INVENTORY_RATIO,
(Decline*1.0)/(nullif((Decline+Growth+Maturity),0)*1.0) as decline_perc,
(Growth*1.0)/(nullif((Decline+Growth+Maturity),0)*1.0) as Growth_perc,
(Maturity*1.0)/(nullif((Decline+Growth+Maturity),0)*1.0) as Maturity_perc,
(pos*1.0)/(nullif((pos+First_mk+further+None_),0)*1.0) as pos_perc,
(First_mk*1.0)/(nullif((pos+First_mk+further+None_),0)*1.0) as First_perc,
(further*1.0)/(nullif((pos+First_mk+further+None_),0)*1.0) as further_perc,
(None_*1.0)/(nullif((pos+First_mk+further+None_),0)*1.0) as Regular_perc,

b.[National Events],b.[Public Holidays],

c.FISCAL_MONTH as month_flag

FROM 
(
	select distinct Dept_Desc,cluster_key,fiscal_year,FISCAL_WEEK,
	sum(GROSS_SALES_UNITS) AS GROSS_SALES_UNITS,
	case when sum(GROSS_SALES_UNITS)>0 then SUM((GROSS_SALES_UNITS*1.0)*(Regular_price*1.0))/sum(GROSS_SALES_UNITS)
	when sum(GROSS_SALES_UNITS)=0 then avg(Regular_price)
	end AS Weighted_regular_Price,
	case when sum(GROSS_SALES_UNITS)>0 then SUM((GROSS_SALES_UNITS*1.0)*(Final_price*1.0))/sum(GROSS_SALES_UNITS)
    when sum(GROSS_SALES_UNITS)=0 then avg(Final_price)
	end AS Weighted_final_Price,
	sum(EOP_DC_ON_ORDER_UNITS) EOP_DC_ON_ORDER_UNITS,
	SUM(INVENTORY) INVENTORY,
	AVG(AGE_WEEKS*1.0) AGE_WEEKS,
	#avg(weeks_in_business*1.0) weeks_in_business,
	count(case when Cycle_Type='D' then MERCHANDISE_KEY END) 'Decline',
	count(case when Cycle_Type='G' then MERCHANDISE_KEY END) 'Growth',
	count(case when Cycle_Type='M' then MERCHANDISE_KEY END) 'Maturity',
	count(case when Disc_Type_Flag='POS' then MERCHANDISE_KEY end) 'pos',
	count(case when Disc_Type_Flag='First' then MERCHANDISE_KEY end) 'First_mk',
	count(case when Disc_Type_Flag='Further' then MERCHANDISE_KEY end) 'Further',
	count(case when Disc_Type_Flag='None' then MERCHANDISE_KEY end) 'None_'
	from 
		(select a.*,
		case when b.no_link_lines<10 then concat(a.dept_key,'_',1)
		when b.no_link_lines >=10 and b.no_link_lines<20 then concat(a.cat_key,'_',1)
		when b.no_link_lines >= 20 then concat(a.cat_key,'_',a.cluster_number)
		end as cluster_key
		----,c.weeks_in_business
		from Regression_product_level a
		join 
		(
		select distinct dept_key,cat_key,count(distinct link_line) as no_link_lines
		from Regression_product_level
		group by dept_key,cat_key
		
		) b
		on a.Dept_key=b.Dept_key
		and a.cat_key=b.cat_key

		---join 
		--#(
		--#select merchandise_key,count(distinct concat(fiscal_year,fiscal_week)) as weeks_in_business
		--#from Regression_product_level
		--#group by merchandise_key
		--#)c

	    ---on a.merchandise_key=c.merchandise_key
		)a
	
	group by Dept_Desc,cluster_key,fiscal_year,FISCAL_WEEK
) A
left JOIN [dbo].[Holidays] B
ON A.Fiscal_year=B.Fiscal_Year
AND A.Fiscal_Week=B.Fiscal_Week

left join cal c
ON concat(a.Fiscal_year,a.Fiscal_Week)=concat(c.Fiscal_year,c.Fiscal_Week)
) a


select a.*,
case when md_discount>b.median_disc then 1
else 0
end as high_disc_flag
into Regression_ad_type_1
from Regression_ad_type_1_interim a
join
(select dept_desc,max(MD_DISCOUNT) as median_disc from 
	(
	select dept_desc,MD_DISCOUNT,ntile(4) over(partition by dept_desc order by MD_DISCOUNT) quartile
	from Regression_ad_type_1_interim
	)a
where quartile=2
group by dept_desc)b
on a.dept_desc=b.dept_desc
---------------------------final ad which was being used for regression------------

select *,(pos_perc*MD_DISCOUNT) as pos_disc,(First_perc*MD_DISCOUNT) as first_disc,
(further_perc*MD_DISCOUNT) as further_disc,
case when holiday_flag>=1 then 1
else 0 end as Holiday
into Regression_ad_type_1_changed
from Regression_ad_type_1

select distinct dept_desc from Regression_ad_type_1_changed


-----------table with category key and cluster key mapping----------


select distinct cat_key,cluster_key
into cat_key_cluster_key_mapping
 from

        (select a.*,
		case when b.no_link_lines<10 then concat(a.dept_key,'_',1)
		when b.no_link_lines >=10 and b.no_link_lines<20 then concat(a.cat_key,'_',1)
		when b.no_link_lines >= 20 then concat(a.cat_key,'_',a.cluster_number)
		end as cluster_key
		----,c.weeks_in_business
		from Regression_product_level a
		join 
		(
		select distinct dept_key,cat_key,count(distinct link_line) as no_link_lines
		from Regression_product_level
		group by dept_key,cat_key
		
		) b
		on a.Dept_key=b.Dept_key
		and a.cat_key=b.cat_key)a


--------------------ad with growth maturity and decline column added---------

select a.*,
CASE WHEN AGE_WEEKS<=INFL1 THEN 'G'
	WHEN AGE_WEEKS>INFL1 AND [age_weeks]<=INFL2 THEN 'M'
	WHEN AGE_WEEKS>INFL2 THEN 'D'
	ELSE 'None'
	end as phase_for_category
into Regression_ad_type_1_changed_phase
from Regression_ad_type_1_changed a

join (select a.cluster_key,avg(b.infl1) infl1,avg(b.infl2) infl2
      from cat_key_cluster_key_mapping a
      join cat_age_interim_tab b
      on a.cat_key=b.cat_key
	  group by cluster_key
	  )b

on a.cluster_key=b.cluster_key
--113925

------------------------data for type 2 regression-----------

drop table Regression_ad_type_2

Select *,
lag(INVENTORY_RATIO,1,0) over(partition by Dept_Desc,cluster_key,Disc_Type_Flag order by a.fiscal_year,a.fiscal_week) as inventory_ratio_lag,
lag(INVENTORY,1,0) over(partition by Dept_Desc,cluster_key,Disc_Type_Flag order by a.fiscal_year,a.fiscal_week) as inventory_lag
,dense_rank() over(partition by Dept_Desc,cluster_key order by a.fiscal_year,a.fiscal_week) as Weeks_since_Launch
,case when (MD_DISCOUNT*1.0)>=40 then 1 else 0 end as High_Discount_Flag
,case when [National Events]>=1 then 1
when [Public Holidays]>=1 then 1
else 0
end as holiday_flag
into Regression_ad_type_2
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
b.[National Events],b.[Public Holidays],
c.FISCAL_MONTH as month_flag
FROM 
(
	select distinct Dept_Desc,cluster_key,Disc_Type_Flag,fiscal_year,FISCAL_WEEK,
	sum(GROSS_SALES_UNITS) AS GROSS_SALES_UNITS,
	case when sum(GROSS_SALES_UNITS)>0 then SUM((GROSS_SALES_UNITS*1.0)*(Regular_price*1.0))/sum(GROSS_SALES_UNITS)
	when sum(GROSS_SALES_UNITS)=0 then avg(Regular_price)
	end AS Weighted_regular_Price,
	case when sum(GROSS_SALES_UNITS)>0 then SUM((GROSS_SALES_UNITS*1.0)*(Final_price*1.0))/sum(GROSS_SALES_UNITS)
    when sum(GROSS_SALES_UNITS)=0 then avg(Final_price)
	end AS Weighted_final_Price,
	sum(EOP_DC_ON_ORDER_UNITS) EOP_DC_ON_ORDER_UNITS,
	SUM(INVENTORY) INVENTORY,
	AVG(AGE_WEEKS*1.0) AGE_WEEKS,
	count(case when Cycle_Type='D' then MERCHANDISE_KEY END) 'Decline',
	count(case when Cycle_Type='G' then MERCHANDISE_KEY END) 'Growth',
	count(case when Cycle_Type='M' then MERCHANDISE_KEY END) 'Maturity'
	---count(case when Disc_Type_Flag='POS' then MERCHANDISE_KEY end) 'pos',
	---count(case when Disc_Type_Flag='First' then MERCHANDISE_KEY end) 'First_mk',
	---count(case when Disc_Type_Flag='Further' then MERCHANDISE_KEY end) 'Further'
	from 
		(select a.*,
		case when b.no_link_lines<10 then concat(a.dept_key,'_',1)
		when b.no_link_lines between 10 and 20 then concat(a.cat_key,'_',1)
		when b.no_link_lines> 20 then concat(a.cat_key,'_',a.cluster_number)
		end as cluster_key
		from Regression_product_level a
		join 
		(
		select distinct dept_key,cat_key,count(distinct link_line) as no_link_lines
		from Regression_product_level
		group by dept_key,cat_key
		
		) b
		on a.Dept_key=b.Dept_key
		and a.cat_key=b.cat_key
	
		)a
	
	group by Dept_Desc,cluster_key,Disc_Type_Flag,fiscal_year,FISCAL_WEEK
) A
left JOIN [dbo].[Holidays] B
ON A.Fiscal_year=B.Fiscal_Year
AND A.Fiscal_Week=B.Fiscal_Week

left join cal c
ON concat(a.Fiscal_year,a.Fiscal_Week)=concat(c.Fiscal_year,c.Fiscal_Week)
) a
----256512


select top 10 * from Regression_ad_type_2

select * from [dbo].[Holidays]

--------------------regression ad for seasonality calculation------------

drop table if exists Regression_ad_seasonality_factor;


--select fiscal_year, fiscal_week, month_flag from Regression_ad_seasonality_factor where cat_key=10258
Select *,
lag(INVENTORY_RATIO,1,0) over(partition by Dept_Desc,cat_key order by a.fiscal_year,a.fiscal_week) as inventory_ratio_lag,
lag(INVENTORY,1,0) over(partition by Dept_Desc,cat_key order by a.fiscal_year,a.fiscal_week) as inventory_lag
,rank() over(partition by Dept_Desc,cat_key order by a.fiscal_year,a.fiscal_week) as Weeks_since_Launch
,case when (MD_DISCOUNT*1.0)>=40 then 1 else 0 end as High_Discount_Flag
,case when [National Events]>[Public Holidays] then [National Events]
else [Public Holidays]
end as holiday_flag
into Regression_ad_seasonality_factor
from
(
SELECT A.*,
((Weighted_regular_Price-Weighted_final_Price)/NULLIF(Weighted_regular_Price,0))*100 AS MD_DISCOUNT,

(INVENTORY*1.0)/(NULLIF(GROSS_SALES_UNITS,0)*1.0) AS INVENTORY_RATIO,
(Decline*1.0)/(nullif((Decline+Growth+Maturity),0)*1.0) as decline_perc,
(Growth*1.0)/(nullif((Decline+Growth+Maturity),0)*1.0) as Growth_perc,
(Maturity*1.0)/(nullif((Decline+Growth+Maturity),0)*1.0) as Maturity_perc,
(pos*1.0)/(nullif((pos+First_mk+further+None_),0)*1.0) as pos_perc,
(First_mk*1.0)/(nullif((pos+First_mk+further+None_),0)*1.0) as First_perc,
(further*1.0)/(nullif((pos+First_mk+further+None_),0)*1.0) as further_perc,
(None_*1.0)/(nullif((pos+First_mk+further+None_),0)*1.0) as Regular_perc,

b.[National Events],b.[Public Holidays],
c.FISCAL_MONTH as month_flag

FROM 
(
	select distinct Dept_Desc,cat_key,fiscal_year,FISCAL_WEEK,
	sum(GROSS_SALES_UNITS) AS GROSS_SALES_UNITS,
	case when sum(GROSS_SALES_UNITS)>0 then SUM((GROSS_SALES_UNITS*1.0)*(Regular_price*1.0))/sum(GROSS_SALES_UNITS)
	when sum(GROSS_SALES_UNITS)=0 then avg(Regular_price)
	end AS Weighted_regular_Price,
	case when sum(GROSS_SALES_UNITS)>0 then SUM((GROSS_SALES_UNITS*1.0)*(Final_price*1.0))/sum(GROSS_SALES_UNITS)
    when sum(GROSS_SALES_UNITS)=0 then avg(Final_price)
	end AS Weighted_final_Price,
	sum(EOP_DC_ON_ORDER_UNITS) EOP_DC_ON_ORDER_UNITS,
	SUM(INVENTORY) INVENTORY,
	AVG(AGE_WEEKS*1.0) AGE_WEEKS,
	count(case when Cycle_Type='D' then MERCHANDISE_KEY END) 'Decline',
	count(case when Cycle_Type='G' then MERCHANDISE_KEY END) 'Growth',
	count(case when Cycle_Type='M' then MERCHANDISE_KEY END) 'Maturity',
	count(case when Disc_Type_Flag='POS' then MERCHANDISE_KEY end) 'pos',
	count(case when Disc_Type_Flag='First' then MERCHANDISE_KEY end) 'First_mk',
	count(case when Disc_Type_Flag='Further' then MERCHANDISE_KEY end) 'Further',
	count(case when Disc_Type_Flag='None' then MERCHANDISE_KEY end) 'None_'
	from Regression_product_level
	group by Dept_Desc,cat_key,fiscal_year,FISCAL_WEEK
) A
left JOIN [dbo].[Holidays] B
ON A.Fiscal_year=B.Fiscal_Year
AND A.Fiscal_Week=B.Fiscal_Week

left join cal c
ON concat(a.Fiscal_year,a.Fiscal_Week)=concat(c.Fiscal_year,c.Fiscal_Week)
) a


select top 100 * from Regression_product_level