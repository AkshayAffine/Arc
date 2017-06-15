-----------product cluster level mapping-----------

select a.*,
		case when b.no_link_lines<10 then concat(a.dept_key,'_',1)
		when b.no_link_lines between 10 and 20 then concat(a.cat_key,'_',1)
		when b.no_link_lines> 20 then concat(a.cat_key,'_',a.cluster_number)
		end as cluster_key
		into product_level_with_cluster_key
		from Regression_product_level a
		join 
		(
		select distinct dept_key,cat_key,count(distinct link_line) as no_link_lines
		from Regression_product_level
		group by dept_key,cat_key
		
		) b
		on a.Dept_key=b.Dept_key
		and a.cat_key=b.cat_key


-----------------------BASE TABLE FOR VALIDATION-------------

DROP TABLE BASE_TABLE_FOR_VALIDATION_ALL_DEPTS

select *
, case when BASELINE_WSL_first is null then (min(age) over(partition by merchandise_key,season_flag order by fiscal_year,fiscal_week))-1
  else BASELINE_WSL_first
  end as baseline_wsl
, (Discount*1.0) - (case when CD*1.0 is null then Discount*1.0 else CD*1.0 end) as Disc_Change
,case when Disc_Type_Flag = 'POS' then PE_POS
	  when Disc_Type_Flag = 'First' then PE_first
	  when Disc_Type_Flag = 'Further' then PE_further
	  else PE
	  end as PE_final
,case when Holiday = 1 then ((SI*1.00000) * (Holiday_Factor*1.00000))
	  else (SI*1.00000)
	  end as SI_final

INTO BASE_TABLE_FOR_VALIDATION_ALL_DEPTS
from
(
select distinct a.*
,A.AGE_WEEKS AS AGE,
H.AGE_WEEKS AS BASELINE_WSL_first,
A.CYCLE_TYPE AS Current_PLC,

H.CYCLE_TYPE AS Prev_PLC_stage,
b.FISCAL_MONTH,
d.cluster_key,
case when c.[National Events]>=1 then 1
when c.[Public Holidays]>=1 then 1
else 0
end as holiday,
cast(E.final_Co_eff_md_discount as float) as pe,
CAST(E.final_Co_eff_pos AS FLOAT) as pe_pos,
CAST(E.final_Co_eff_first AS FLOAT) as pe_FIRST,
CAST(E.final_Co_eff_further AS FLOAT) as pe_FURTHER,

G.new_ssn_exp as SI,
exp(CAST(i.holiday_coefficient AS FLOAT)) as holiday_factor,
cd_discount as cd,
i.[es fcast] as BaseSales_es_fcast,
K.ES_MA as BaseSales_MA,
K.ES_Med as BaseSales_Med,
T.AGE_WEEKS AS AGE_CO_EFFECIENT,
T.Final_G_coeff,T.Final_M_coeff

from
(
select dept_key,cat_key,merchandise_key,Fiscal_year,Fiscal_week,
case when Fiscal_year=2015 and Fiscal_week between 17 and 21 then 'AW2015'--------------take one week extra compared to that of sales period---
when Fiscal_year=2014 and Fiscal_week between 42 and 48 then 'SS2014'--------------take one week extra compared to that of sales period---
when Fiscal_year=2015 and Fiscal_week between 42 and 47 then 'SS2015'--------------take one week extra compared to that of sales period---
when Fiscal_year=2014 and Fiscal_week between 16 and 21 then 'AW2014'--------------take one week extra compared to that of sales period---
end as season_flag,gross_sales_units,
disc_type_flag,AGE_WEEKS,CYCLE_TYPE_new as cycle_type,
(Regular_price-Final_Price)/nullif(Regular_price,0) as discount
from (select *,
	CASE WHEN [age_weeks]<INFL1 THEN 'G'
	WHEN [age_weeks]>=INFL1 AND [age_weeks]<INFL2 THEN 'M'
	WHEN [age_weeks]>=INFL2 THEN 'D'
	ELSE 'None'
	end as Cycle_Type_new
	       from Regression_product_level )a
--group by Dept_key,cat_key,merchandise_key,Fiscal_year,Fiscal_week
)A
join cal b
on a.Fiscal_year=b.Fiscal_year
and a.Fiscal_week=b.Fiscal_week

left JOIN [dbo].[Holidays] c
ON A.Fiscal_year=c.Fiscal_Year
AND A.Fiscal_Week=c.Fiscal_Week

LEFT join (select distinct merchandise_key,cluster_key from  product_level_with_cluster_key) d
on a.merchandise_key=d.merchandise_key

LEFT JOIN final_reassigned_coeff_wPLC E
ON CONCAT(E.Cat_key,'_',E.Cluster_key)=D.cluster_key

LEFT join [dbo].[PLC_n_Age_Factors] T 
on D.CLUSTER_KEY=T.CLUSTER_KEY

LEFT join final_si_capped g---------seasonality_index 
on a.cat_key=g.cat_key
and b.fiscal_month=g.period

left join 
	(SELECT * FROM 
	(select dept_key,cat_key,merchandise_key,Fiscal_year,Fiscal_week,
	case when Fiscal_year=2015 and Fiscal_week=16 then 'AW2015'
	when Fiscal_year=2014 and Fiscal_week =41 then 'SS2014'
	when Fiscal_year=2015 and Fiscal_week =41 then 'SS2015'
	when Fiscal_year=2014 and Fiscal_week =15 then 'AW2014'
	end as season_flag,
	gross_sales_units,CYCLE_TYPE_new as cycle_type,AGE_WEEKS,
	(Regular_price-Final_Price)/nullif(Regular_price,0) as cd_discount
	from (select *,
	CASE WHEN [age_weeks]<INFL1 THEN 'G'
	WHEN [age_weeks]>=INFL1 AND [age_weeks]<INFL2 THEN 'M'
	WHEN [age_weeks]>=INFL2 THEN 'D'
	ELSE 'None'
	end as Cycle_Type_new
	       from Regression_product_level )a
	)A WHERE SEASON_FLAG IS NOT NULL
	---AND merchandise_key=1404954
)h
on a.merchandise_key=h.merchandise_key
and a.season_flag=h.season_flag

LEFT join 
(SELECT *,
case when Fiscal_year=2015 and Fiscal_week=17 then 'AW2015'
	when Fiscal_year=2014 and Fiscal_week =42 then 'SS2014'
	when Fiscal_year=2015 and Fiscal_week =42 then 'SS2015'
	when Fiscal_year=2014 and Fiscal_week =16 then 'AW2014' 
end as season_flag
FROM [dbo].[Base_0206_ES3]) i ------es baseline------
on a.cat_key=i.Cat_key
and a.merchandise_key=i.MERCHANDISE_KEY
and a.SEASON_FLAG=I.season_flag

LEFT join 
(SELECT *,
case when Fiscal_year=2015 and Fiscal_week=17 then 'AW2015'
	when Fiscal_year=2014 and Fiscal_week =42 then 'SS2014'
	when Fiscal_year=2015 and Fiscal_week =42 then 'SS2015'
	when Fiscal_year=2014 and Fiscal_week =16 then 'AW2014' 
end as season_flag
FROM [dbo].[Base_0206_ma1]) k
on a.cat_key=k.Cat_key
and a.merchandise_key=k.MERCHANDISE_KEY
and a.SEASON_FLAG=K.season_flag

where a.season_flag is not null
-----order by cat_key,merchandise_key,Fiscal_year,Fiscal_week
)a
order by cat_key,merchandise_key,Fiscal_year,Fiscal_week

select count(distinct merchandise_key) from FINAL_VALIDATION_TABLE
where dept_key in (145,161,131,133)



-------------------final validation table code----------



SELECT *,
case when MAPE_ES<-0.5 then -3
when MAPE_ES<-0.3 then -2
when MAPE_ES<0 then -1
when MAPE_ES<0.3 then 1
when MAPE_ES<0.5 then 2
else 3
end as mape_buckett_es,

case when MAPE_MA<-0.5 then -3
when MAPE_MA<-0.3 then -2
when MAPE_MA<0 then -1
when MAPE_MA<0.3 then 1
when MAPE_MA<0.5 then 2
else 3
end as mape_buckett_ma,

case when MAPE_MED<-0.5 then -3
when MAPE_MED<-0.3 then -2
when MAPE_MED<0 then -1
when MAPE_MED<0.3 then 1
when MAPE_MED<0.5 then 2
else 3
end as mape_buckett_med

INTO FINAL_VALIDATION_TABLE

FROM 
(
SELECT *,
(FINAL_PRED_ES-GROSS_SALES_UNITS)/NULLIF(GROSS_SALES_UNITS,0) AS MAPE_ES,
(FINAL_PRED_MA-GROSS_SALES_UNITS)/NULLIF(GROSS_SALES_UNITS,0) AS MAPE_MA,
(FINAL_PRED_MED-GROSS_SALES_UNITS)/NULLIF(GROSS_SALES_UNITS,0) AS MAPE_MED

FROM 
(
SELECT *,

coalesce(PE_SALES_ES,SI_ADJ_ES_FCST,PLC_SALES_ES_FCAST_STAGE_FACTOR,PLC_SALES_ES_FCAST_AGE_FACTOR) AS FINAL_PRED_ES,
coalesce(PE_SALES_MA,SI_ADJ_MA_STAGE,PLC_SALES_MA_STAGE_FACTOR,PLC_SALES_MA_AGE_FACTOR) AS FINAL_PRED_MA,
coalesce(PE_SALES_MED,SI_ADJ_MED_STAGE,PLC_SALES_MED_STAGE_FACTOR,PLC_SALES_MED_AGE_FACTOR) AS FINAL_PRED_MED

FROM
(
SELECT *,

EXP(PE_ADJ*DISC_CHANGE*100)*SI_ADJ_ES_FCST PE_SALES_ES,
EXP(PE_ADJ*DISC_CHANGE*100)*SI_ADJ_MA_STAGE PE_SALES_MA,
EXP(PE_ADJ*DISC_CHANGE*100)*SI_ADJ_MED_STAGE AS PE_SALES_MED

FROM
(
SELECT *,
SI_final*PLC_SALES_ES_FCAST_STAGE_FACTOR AS SI_ADJ_ES_FCST,
SI_final*PLC_SALES_MA_STAGE_FACTOR AS SI_ADJ_MA_STAGE,
SI_final*PLC_SALES_MED_STAGE_FACTOR AS SI_ADJ_MED_STAGE

FROM
(
SELECT *,
(EXP(CURRENT_COEFF)/EXP(PREV_PLC_COEFF))*PLC_SALES_ES_FCAST_AGE_FACTOR AS PLC_SALES_ES_FCAST_STAGE_FACTOR,
(EXP(CURRENT_COEFF)/EXP(PREV_PLC_COEFF))*PLC_SALES_MA_AGE_FACTOR AS PLC_SALES_MA_STAGE_FACTOR,
(EXP(CURRENT_COEFF)/EXP(PREV_PLC_COEFF))*PLC_SALES_MED_AGE_FACTOR AS PLC_SALES_MED_STAGE_FACTOR

FROM 
(
SELECT *,

PE_FINAL AS PE_adj,
CAST(BASESALES_ES_FCAST AS FLOAT)*EXP(CAST(Change_in_WSL AS INT)*CAST(AGE_CO_EFFECIENT AS FLOAT)) AS PLC_SALES_ES_FCAST_AGE_FACTOR,
CAST(BASESALES_MA AS FLOAT)*EXP(CAST(Change_in_WSL AS INT)*CAST(AGE_CO_EFFECIENT AS FLOAT)) AS PLC_SALES_MA_AGE_FACTOR,
CAST(BASESALES_MED AS FLOAT)*EXP(CAST(Change_in_WSL AS INT)*CAST(AGE_CO_EFFECIENT AS FLOAT)) AS PLC_SALES_MED_AGE_FACTOR,

CASE WHEN Current_PLC='D' THEN 0
WHEN Current_PLC='G' THEN Final_G_coeff
WHEN Current_PLC='M' THEN Final_M_coeff
END AS CURRENT_COEFF,

CASE WHEN Prev_PLC_stage='D' THEN 0
WHEN Prev_PLC_stage='G' THEN Final_G_coeff
WHEN Prev_PLC_stage='M' THEN Final_M_coeff
END AS PREV_PLC_COEFF

FROM
(select *,cast(age as int)-cast(baseline_wsl as int) as change_in_wsl from BASE_TABLE_FOR_VALIDATION_ALL_DEPTS)a 
---WHERE merchandise_key=1601863

)A
)A
)A
)A
)A
)A

select dept_key,season_flag,sum(FINAL_PRED_ES) FINAL_PRED_ES,sum(final_pred_ma) final_pred_ma,sum(FINAL_PRED_MED) FINAL_PRED_MED
from FINAL_VALIDATION_TABLE
where dept_key in (131,133,145,161)
---and season_flag in ('AW2014')
group by dept_key,season_flag
order by dept_key,season_flag 



----------------------------VALIDATION SUMMARY season flag level-------------------


select SEASON_FLAG,mape_buckett_mED, count(distinct merchandise_key) from 
(
select *,
case when MAPE_ES is null then 0
when MAPE_ES<-0.5 then -3
when MAPE_ES<-0.3 then -2
when MAPE_ES<0 then -1
when MAPE_ES<0.3 then 1
when MAPE_ES<0.5 then 2
else 3
end as mape_buckett_es,

case when MAPE_ma is null then 0
when MAPE_MA<-0.5 then -3
when MAPE_MA<-0.3 then -2
when MAPE_MA<0 then -1
when MAPE_MA<0.3 then 1
when MAPE_MA<0.5 then 2
else 3
end as mape_buckett_ma,

case when MAPE_med is null then 0
when MAPE_MED<-0.5 then -3
when MAPE_MED<-0.3 then -2
when MAPE_MED<0 then -1
when MAPE_MED<0.3 then 1
when MAPE_MED<0.5 then 2
else 3
end as mape_buckett_med


from 
(
select SEASON_FLAG,merchandise_key,sum(gross_sales_units) as gross_sales_units,
sum(final_pred_es) as final_pred_es ,
sum(FINAL_PRED_MA) as FINAL_PRED_MA,
sum(FINAL_PRED_MED) as FINAL_PRED_Med,
case when sum(gross_sales_units) =0 then 0.0 
when sum(FINAL_PRED_MA) is null then -1.0 
else (sum(FINAL_PRED_MA)-sum(gross_sales_units))/nullif(sum(gross_sales_units),0) end as mape_ma,
case when sum(gross_sales_units) =0 then 0.0 
when sum(FINAL_PRED_Med) is null then -1.0 
else (sum(FINAL_PRED_Med)-sum(gross_sales_units))/nullif(sum(gross_sales_units),0) end as mape_med,
case when sum(gross_sales_units) =0 then 0.0 
when sum(final_pred_es) is NULL then -1.0 
else (sum(final_pred_es)-sum(gross_sales_units))/nullif(sum(gross_sales_units),0) end as mape_es

from FINAL_VALIDATION_TABLE
where dept_key in (145,161,131,133)
group by SEASON_FLAG,merchandise_key
)a
)a

WHERE SEASON_FLAG = 'AW2015'
group by SEASON_FLAG,mape_buckett_mED
order by SEASON_FLAG,mape_buckett_mED




--------------------------validarion summary overall level---------------


select mape_buckett_ma, count(distinct merchandise_key) from 
(
select *,
case when MAPE_ES is null then 0
when MAPE_ES<-0.5 then -3
when MAPE_ES<-0.3 then -2
when MAPE_ES<0 then -1
when MAPE_ES<0.3 then 1
when MAPE_ES<0.5 then 2
else 3
end as mape_buckett_es,

case when MAPE_ma is null then 0
when MAPE_MA<-0.5 then -3
when MAPE_MA<-0.3 then -2
when MAPE_MA<0 then -1
when MAPE_MA<0.3 then 1
when MAPE_MA<0.5 then 2
else 3
end as mape_buckett_ma,

case when MAPE_med is null then 0
when MAPE_MED<-0.5 then -3
when MAPE_MED<-0.3 then -2
when MAPE_MED<0 then -1
when MAPE_MED<0.3 then 1
when MAPE_MED<0.5 then 2
else 3
end as mape_buckett_med


from 
(
select merchandise_key,sum(gross_sales_units) as gross_sales_units,
sum(final_pred_es) as final_pred_es ,
sum(FINAL_PRED_MA) as FINAL_PRED_MA,
sum(FINAL_PRED_MED) as FINAL_PRED_Med,
case when sum(gross_sales_units) =0 then 0.0 
---when sum(FINAL_PRED_MA) is null then -1.0 
else (sum(FINAL_PRED_MA)-sum(gross_sales_units))/nullif(sum(gross_sales_units),0) end as mape_ma,
case when sum(gross_sales_units) =0 then 0.0 
---when sum(FINAL_PRED_Med) is null then -1.0 
else (sum(FINAL_PRED_Med)-sum(gross_sales_units))/nullif(sum(gross_sales_units),0) end as mape_med,
case when sum(gross_sales_units) =0 then 0.0 
---when sum(final_pred_es) is NULL then -1.0 
else (sum(final_pred_es)-sum(gross_sales_units))/nullif(sum(gross_sales_units),0) end as mape_es

from FINAL_VALIDATION_TABLE
where dept_key in (145,161,131,133)
group by merchandise_key
)a
)a
--where mape_buckett_es = 0
group by mape_buckett_ma
order by mape_buckett_ma

--------------------------------------overall error rate---------

select (sum(FINAL_PRED_MA)-sum(gross_sales_units))/nullif(sum(gross_sales_units),0) mape_ma,
(sum(FINAL_PRED_Med)-sum(gross_sales_units))/nullif(sum(gross_sales_units),0) mape_med,
(sum(final_pred_es)-sum(gross_sales_units))/nullif(sum(gross_sales_units),0) mape_es

from FINAL_VALIDATION_TABLE
where dept_key in (145,161,131,133)

-----------------------overall error by seasons------------

select season_flag,(sum(FINAL_PRED_MA)-sum(gross_sales_units))/nullif(sum(gross_sales_units),0) mape_ma,
(sum(FINAL_PRED_Med)-sum(gross_sales_units))/nullif(sum(gross_sales_units),0) mape_med,
(sum(final_pred_es)-sum(gross_sales_units))/nullif(sum(gross_sales_units),0) mape_es

from FINAL_VALIDATION_TABLE
where dept_key in (145,161,131,133)
group by season_flag


------------------------overall error by department-season---------

select dept_key,season_flag,(sum(FINAL_PRED_MA)-sum(gross_sales_units))/nullif(sum(gross_sales_units),0) mape_ma,
(sum(FINAL_PRED_Med)-sum(gross_sales_units))/nullif(sum(gross_sales_units),0) mape_med,
(sum(final_pred_es)-sum(gross_sales_units))/nullif(sum(gross_sales_units),0) mape_es

from FINAL_VALIDATION_TABLE
where dept_key in (145,161,131,133)
group by dept_key,season_flag
order by dept_key,season_flag
