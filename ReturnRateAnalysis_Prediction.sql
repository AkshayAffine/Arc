use TPC_Arcadia;

drop table if exists Sac_Overall_rr
--Overall RR in MD period and Reg
select Dept_desc ,cat_key ,cat_desc --,line 
,MD_PERIOD_FLAG 
,avg(weeks_in_sales) as weeks_in_sales
,sum(net_sales_units) as net_sales_units 
,sum(gross_sales_units) as gross_sales_units
,(sum(gross_sales_units)-sum(net_sales_units)) as Return_Units
,sum(Returns_post_2wk) as Returns_post_2wk
,case when sum(md_units) = 0 then 0 
else sum(MD_disc_weighted)*1.0/sum(md_units) end as MD_disc_weighted
,case when sum(gross_sales_units) = 0 then 0 
else sum(gross_sales_dollars)*1.0/sum(gross_sales_units) end as avg_price
,case when sum(full_price_units) = 0 then 0 
else sum(full_price_weighted)*1.0/sum(full_price_units) end as weighted_Full_price
,case when sum(gross_sales_units) = 0 then 0 
else sum(Returns_post_2wk)*1.0/sum(gross_sales_units) end as RR
into Sac_Overall_RR
from 
	(
	select Dept_desc,cat_key ,cat_desc,line,MD_PERIOD_FLAG,count(distinct concat(fiscal_year,fiscal_week)) as weeks_in_sales
	,sum(net_sales_units) as net_sales_units ,sum(gross_sales_units) as gross_sales_units
	,sum(Returns_post_2wk) as Returns_post_2wk
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
			,LEAD(gross_sales_units-net_sales_units,2) 
			over(partition by merchandise_key order by fiscal_year,fiscal_week) as Returns_post_2wk
			from
			[dbo].[Final_master_AD_2]
			where merchandise_key is not null
			--and line = 1606270
			) a
		)a
	group by Dept_desc ,cat_key ,cat_desc,line,MD_PERIOD_FLAG
	) a
--where cat_key=14930
group by Dept_desc ,cat_key ,cat_desc --, line 
,MD_PERIOD_FLAG
;


--#############################################################################################
--Overall RR in MD period and Reg - 6 weeks cut-off
drop table if exists Sac_Overall_rr_6wk
select Dept_desc ,cat_key ,cat_desc --,line 
,MD_PERIOD_FLAG 
,avg(weeks_in_sales) as weeks_in_sales
,sum(net_sales_units) as net_sales_units 
,sum(gross_sales_units) as gross_sales_units
,(sum(gross_sales_units)-sum(net_sales_units)) as Return_Units
,sum(Returns_post_2wk) as Returns_post_2wk
,case when sum(md_units) = 0 then 0 
else sum(MD_disc_weighted)*1.0/sum(md_units) end as MD_disc_weighted
,case when sum(gross_sales_units) = 0 then 0 
else sum(gross_sales_dollars)*1.0/sum(gross_sales_units) end as avg_price
,case when sum(full_price_units) = 0 then 0 
else sum(full_price_weighted)*1.0/sum(full_price_units) end as weighted_Full_price
into Sac_Overall_rr_6wk
from 
	(
	select Dept_desc,cat_key ,cat_desc,line,MD_PERIOD_FLAG,count(distinct concat(fiscal_year,fiscal_week)) as weeks_in_sales
	,sum(net_sales_units) as net_sales_units ,sum(gross_sales_units) as gross_sales_units
	,sum(Returns_post_2wk) as Returns_post_2wk
	,sum(gross_sales_dollars) as gross_sales_dollars
	,sum(gross_sales_units * coalesce(md_discount,0))*1.0 as MD_disc_weighted
	,sum(case when md_discount is null or md_discount=0 then 0 else gross_sales_units end) as md_units
	,sum(gross_sales_units * coalesce(full_price,0))*1.0 as full_price_weighted
	,sum(case when full_price is null or full_price=0 then 0 else gross_sales_units end) as full_price_units
	from
		(
		select *
		,rank() over(partition by merchandise_key,MD_PERIOD_FLAG order by fiscal_year desc,fiscal_week desc) as rnk1
		,rank() over(partition by merchandise_key,MD_PERIOD_FLAG order by fiscal_year ,fiscal_week) as rnk2 
		from
			(
			select *,
			case when coalesce(md_taken_flag,pos_flag) is null then 0
			else 1
			end as MD_PERIOD_FLAG
			from 
				(select *,LEAD(md_taken_flag,2) 
				over(partition by merchandise_key order by fiscal_year,fiscal_week) as pos_flag
				,LEAD(gross_sales_units-net_sales_units,2) 
				over(partition by merchandise_key order by fiscal_year,fiscal_week) as Returns_post_2wk
				from
				[dbo].[Final_master_AD_2]
				where merchandise_key is not null
				--and line = 1606270
				) a
			)a
		) a
	where case when MD_PERIOD_FLAG=0 and rnk1<=6 then 1
	when MD_PERIOD_FLAG=1 and rnk2<=6 then 1 else 0 end =1
	group by Dept_desc ,cat_key ,cat_desc,line,MD_PERIOD_FLAG
	) a
--where cat_key=14930
group by Dept_desc ,cat_key ,cat_desc --, line 
,MD_PERIOD_FLAG
;


--## creating a base AD
drop table if exists Sac_returns_base_data;
select *,
case when coalesce(md_taken_flag,pos_flag) is null then 0
else 1
end as MD_PERIOD_FLAG
into Sac_returns_base_data
from 
	(select *,LEAD(md_taken_flag,2) 
	over(partition by merchandise_key order by fiscal_year,fiscal_week) as pos_flag
	,LEAD(gross_sales_units-net_sales_units,2) 
	over(partition by merchandise_key order by fiscal_year,fiscal_week) as Returns_post_2wk
	from
	[dbo].[Final_master_AD_2]
	where merchandise_key is not null
	--and line = 1606270
	) a
;			


--#############################################################################################
--## Method 1

--## Creating first validation set
select a.* ,c.MD_TAKEN_flag ,b.Reg_RR ,b.MD_RR 
,gross_sales_units* (case when MD_TAKEN_flag is not null then MD_RR else Reg_RR end) as Pred_Returns
,case when Returns_post_2wk =0 then 0 else
ABS(Returns_post_2wk-(gross_sales_units* (case when MD_TAKEN_flag is not null then MD_RR else Reg_RR end)))/Returns_post_2wk end as Error 
from 
(
select line ,Cat_key
,sum(gross_sales_units) as gross_sales_units 
,sum(Returns_post_2wk) as Returns_post_2wk 
,count(*) as wk_cnt
from Sac_returns_base_data 
where FISCAL_YEAR=2014 and FISCAL_WEEK between 39 and 44
group by line ,Cat_key
having count(*) =6
) a
join 
(
select Cat_key ,sum(case when MD_PERIOD_FLAG=0 then rr end) as Reg_RR
,sum(case when MD_PERIOD_FLAG=1 then rr end) as MD_RR  
from Sac_Overall_RR group by Cat_key
) b
on a.Cat_key=b.Cat_key
join
(select distinct line ,MD_TAKEN_flag from Sac_returns_base_data
where FISCAL_YEAR=2014 and FISCAL_WEEK =41) c
on a.Line=c.line
where gross_sales_units>0

--##Creating second validation set
select a.* ,c.MD_TAKEN_flag ,b.Reg_RR ,b.MD_RR 
,gross_sales_units* (case when MD_TAKEN_flag is not null then MD_RR else Reg_RR end) as Pred_Returns
,case when Returns_post_2wk =0 then 0 else
ABS(Returns_post_2wk-(gross_sales_units* (case when MD_TAKEN_flag is not null then MD_RR else Reg_RR end)))/Returns_post_2wk end as Error 
from 
(
select line ,Cat_key
,sum(gross_sales_units) as gross_sales_units 
,sum(Returns_post_2wk) as Returns_post_2wk 
,count(*) as wk_cnt
from Sac_returns_base_data 
where FISCAL_YEAR=2015 and FISCAL_WEEK between 39 and 44
group by line ,Cat_key
having count(*) =6
) a
join 
(
select Cat_key ,sum(case when MD_PERIOD_FLAG=0 then rr end) as Reg_RR
,sum(case when MD_PERIOD_FLAG=1 then rr end) as MD_RR  
from Sac_Overall_RR group by Cat_key
) b
on a.Cat_key=b.Cat_key
join
(select distinct line ,MD_TAKEN_flag from Sac_returns_base_data
where FISCAL_YEAR=2015 and FISCAL_WEEK =41) c
on a.Line=c.line
where gross_sales_units>0



--#############################################################################################
--## Method 2 - 13wk MA

--## Creating first validation set
select a.* ,c.MD_TAKEN_flag ,b.pred_RR
,gross_sales_units*b.pred_RR as Pred_Returns
,case when Returns_post_2wk =0 then 0 else
ABS(Returns_post_2wk-(gross_sales_units*b.pred_RR))/Returns_post_2wk end as Error 
from 
(
select line ,Cat_key
,sum(gross_sales_units) as gross_sales_units 
,sum(Returns_post_2wk) as Returns_post_2wk 
,count(*) as wk_cnt
from Sac_returns_base_data 
where FISCAL_YEAR=2014 and FISCAL_WEEK between 39 and 44
group by line ,Cat_key
having count(*) =6
) a
join 
(
select cat_key, pred_RR from RR_error_AD_All_wks_MA_post2wks
where FISCAL_WEEK=38 and FISCAL_YEAR=2014
) b
on a.Cat_key=b.Cat_key
join
(select distinct line ,MD_TAKEN_flag from Sac_returns_base_data
where FISCAL_YEAR=2014 and FISCAL_WEEK =41) c
on a.Line=c.line
where gross_sales_units>0



--## Creating second validation set
select a.* ,c.MD_TAKEN_flag ,b.pred_RR
,gross_sales_units*b.pred_RR as Pred_Returns
,case when Returns_post_2wk =0 then 0 else
ABS(Returns_post_2wk-(gross_sales_units*b.pred_RR))/Returns_post_2wk end as Error 
from 
(
select line ,Cat_key
,sum(gross_sales_units) as gross_sales_units 
,sum(Returns_post_2wk) as Returns_post_2wk 
,count(*) as wk_cnt
from Sac_returns_base_data 
where FISCAL_YEAR=2015 and FISCAL_WEEK between 39 and 44
group by line ,Cat_key
having count(*) =6
) a
join 
(
select cat_key, pred_RR from RR_error_AD_All_wks_MA_post2wks
where FISCAL_WEEK=39 and FISCAL_YEAR=2015
) b
on a.Cat_key=b.Cat_key
join
(select distinct line ,MD_TAKEN_flag from Sac_returns_base_data
where FISCAL_YEAR=2015 and FISCAL_WEEK =41) c
on a.Line=c.line
where gross_sales_units>0



--#############################################################################################
--## Method 3 - 13wk MA with MD adj.

--##Creating first validation set
select a.* ,c.MD_TAKEN_flag ,b.pred_RR
,case when MD_TAKEN_flag is null then b.pred_RR else b.pred_RR*(md_rr*1.0/Reg_RR) end as adj_rr
,gross_sales_units*case when MD_TAKEN_flag is null then b.pred_RR else b.pred_RR*(md_rr*1.0/Reg_RR) end as Pred_Returns
,case when Returns_post_2wk =0 then 0 else
ABS(Returns_post_2wk-(gross_sales_units*case when MD_TAKEN_flag is null then b.pred_RR else b.pred_RR*(md_rr/Reg_RR) end))/Returns_post_2wk end as Error 
from 
(
select line ,Cat_key
,sum(gross_sales_units) as gross_sales_units 
,sum(Returns_post_2wk) as Returns_post_2wk 
,count(*) as wk_cnt
from Sac_returns_base_data 
where FISCAL_YEAR=2014 and FISCAL_WEEK between 39 and 44
group by line ,Cat_key
having count(*) =6
) a
join 
(
select cat_key, pred_RR from RR_error_AD_All_wks_MA_post2wks
where FISCAL_WEEK=38 and FISCAL_YEAR=2014
) b
on a.Cat_key=b.Cat_key
join
(select distinct line ,MD_TAKEN_flag from Sac_returns_base_data
where FISCAL_YEAR=2014 and FISCAL_WEEK =41) c
on a.Line=c.line
join
(select Cat_key ,sum(case when MD_PERIOD_FLAG=0 then rr end) as Reg_RR
,sum(case when MD_PERIOD_FLAG=1 then rr end) as MD_RR  
from Sac_Overall_RR group by Cat_key
) d
on a.cat_key=d.cat_key
where gross_sales_units>0


--##Creating second validation set
select a.* ,c.MD_TAKEN_flag ,b.pred_RR 
,case when MD_TAKEN_flag is null then b.pred_RR else b.pred_RR*(md_rr*1.0/Reg_RR) end as adj_rr
,gross_sales_units*case when MD_TAKEN_flag is null then b.pred_RR else b.pred_RR*(md_rr*1.0/Reg_RR) end as Pred_Returns
,case when Returns_post_2wk =0 then 0 else
ABS(Returns_post_2wk-(gross_sales_units*case when MD_TAKEN_flag is null then b.pred_RR else b.pred_RR*(md_rr*1.0/Reg_RR) end))/Returns_post_2wk end as Error 
from 
(
select line ,Cat_key
,sum(gross_sales_units) as gross_sales_units 
,sum(Returns_post_2wk) as Returns_post_2wk 
,count(*) as wk_cnt
from Sac_returns_base_data 
where FISCAL_YEAR=2015 and FISCAL_WEEK between 39 and 44
group by line ,Cat_key
having count(*) =6
) a
join 
(
select cat_key, pred_RR from RR_error_AD_All_wks_MA_post2wks
where FISCAL_WEEK=38 and FISCAL_YEAR=2015
) b
on a.Cat_key=b.Cat_key
join
(select distinct line ,MD_TAKEN_flag from Sac_returns_base_data
where FISCAL_YEAR=2015 and FISCAL_WEEK =41) c
on a.Line=c.line
join
(select Cat_key ,sum(case when MD_PERIOD_FLAG=0 then rr end) as Reg_RR
,sum(case when MD_PERIOD_FLAG=1 then rr end) as MD_RR  
from Sac_Overall_RR group by Cat_key
) d
on a.cat_key=d.cat_key
where gross_sales_units>0


--#############################################################################################
--## Method 4 - Product level 13wk MA with MD adj.

--##Creating first validation set
select a.* ,c.MD_TAKEN_flag ,b.pred_RR
,case when MD_TAKEN_flag is null then b.pred_RR else b.pred_RR*(md_rr*1.0/Reg_RR) end as adj_rr
,gross_sales_units*case when MD_TAKEN_flag is null then b.pred_RR else b.pred_RR*(md_rr*1.0/Reg_RR) end as Pred_Returns
,case when Returns_post_2wk =0 then 0 else
ABS(Returns_post_2wk-(gross_sales_units*case when MD_TAKEN_flag is null then b.pred_RR else b.pred_RR*(md_rr/Reg_RR) end))/Returns_post_2wk end as Error 
from 
(
select line ,Cat_key
,sum(gross_sales_units) as gross_sales_units 
,sum(Returns_post_2wk) as Returns_post_2wk 
,count(*) as wk_cnt
from Sac_returns_base_data 
where FISCAL_YEAR=2014 and FISCAL_WEEK between 39 and 44
group by line ,Cat_key
having count(*) =6
) a
join 
(
select cat_key, line, pred_RR from RR_error_AD_All_wks_MA_post2wks_line
where FISCAL_WEEK=38 and FISCAL_YEAR=2014
) b
on a.line=b.line
join
(select distinct line ,MD_TAKEN_flag from Sac_returns_base_data
where FISCAL_YEAR=2014 and FISCAL_WEEK =41) c
on a.Line=c.line
join
(select Cat_key ,sum(case when MD_PERIOD_FLAG=0 then rr end) as Reg_RR
,sum(case when MD_PERIOD_FLAG=1 then rr end) as MD_RR  
from Sac_Overall_RR group by Cat_key
) d
on a.cat_key=d.cat_key
where gross_sales_units>0


--##Creating second validation set
select a.* ,c.MD_TAKEN_flag ,b.pred_RR
,case when MD_TAKEN_flag is null then b.pred_RR else b.pred_RR*(md_rr*1.0/Reg_RR) end as adj_rr
,gross_sales_units*case when MD_TAKEN_flag is null then b.pred_RR else b.pred_RR*(md_rr*1.0/Reg_RR) end as Pred_Returns
,case when Returns_post_2wk =0 then 0 else
ABS(Returns_post_2wk-(gross_sales_units*case when MD_TAKEN_flag is null then b.pred_RR else b.pred_RR*(md_rr/Reg_RR) end))/Returns_post_2wk end as Error 
from 
(
select line ,Cat_key
,sum(gross_sales_units) as gross_sales_units 
,sum(Returns_post_2wk) as Returns_post_2wk 
,count(*) as wk_cnt
from Sac_returns_base_data 
where FISCAL_YEAR=2015 and FISCAL_WEEK between 39 and 44
group by line ,Cat_key
having count(*) =6
) a
join 
(
select cat_key, line, pred_RR from RR_error_AD_All_wks_MA_post2wks_line
where FISCAL_WEEK=38 and FISCAL_YEAR=2015
) b
on a.line=b.line
join
(select distinct line ,MD_TAKEN_flag from Sac_returns_base_data
where FISCAL_YEAR=2015 and FISCAL_WEEK =41) c
on a.Line=c.line
join
(select Cat_key ,sum(case when MD_PERIOD_FLAG=0 then rr end) as Reg_RR
,sum(case when MD_PERIOD_FLAG=1 then rr end) as MD_RR  
from Sac_Overall_RR group by Cat_key
) d
on a.cat_key=d.cat_key
where gross_sales_units>0



--#############################################################################################
--## Method 5 - Cat level 6wk MA with MD adj.

--##Creating first validation set
select a.* ,c.MD_TAKEN_flag ,b.pred_RR
,case when MD_TAKEN_flag is null then b.pred_RR else b.pred_RR*(md_rr*1.0/Reg_RR) end as adj_rr
,gross_sales_units*case when MD_TAKEN_flag is null then b.pred_RR else b.pred_RR*(md_rr*1.0/Reg_RR) end as Pred_Returns
,case when Returns_post_2wk =0 then 0 else
ABS(Returns_post_2wk-(gross_sales_units*case when MD_TAKEN_flag is null then b.pred_RR else b.pred_RR*(md_rr/Reg_RR) end))/Returns_post_2wk end as Error 
from 
(
select line ,Cat_key
,sum(gross_sales_units) as gross_sales_units 
,sum(Returns_post_2wk) as Returns_post_2wk 
,count(*) as wk_cnt
from Sac_returns_base_data 
where FISCAL_YEAR=2014 and FISCAL_WEEK between 39 and 44
group by line ,Cat_key
having count(*) =6
) a
join 
(
select cat_key, pred_RR from RR_error_AD_All_wks_6WK_MA_post2wks
where FISCAL_WEEK=38 and FISCAL_YEAR=2014
) b
on a.cat_key=b.cat_key
join
(select distinct line ,MD_TAKEN_flag from Sac_returns_base_data
where FISCAL_YEAR=2014 and FISCAL_WEEK =41) c
on a.Line=c.line
join
(select Cat_key ,sum(case when MD_PERIOD_FLAG=0 then rr end) as Reg_RR
,sum(case when MD_PERIOD_FLAG=1 then rr end) as MD_RR  
from Sac_Overall_RR group by Cat_key
) d
on a.cat_key=d.cat_key
where gross_sales_units>0


--##Creating second validation set
select a.* ,c.MD_TAKEN_flag ,b.pred_RR
,case when MD_TAKEN_flag is null then b.pred_RR else b.pred_RR*(md_rr*1.0/Reg_RR) end as adj_rr
,gross_sales_units*case when MD_TAKEN_flag is null then b.pred_RR else b.pred_RR*(md_rr*1.0/Reg_RR) end as Pred_Returns
,case when Returns_post_2wk =0 then 0 else
ABS(Returns_post_2wk-(gross_sales_units*case when MD_TAKEN_flag is null then b.pred_RR else b.pred_RR*(md_rr/Reg_RR) end))/Returns_post_2wk end as Error 
from 
(
select line ,Cat_key
,sum(gross_sales_units) as gross_sales_units 
,sum(Returns_post_2wk) as Returns_post_2wk 
,count(*) as wk_cnt
from Sac_returns_base_data 
where FISCAL_YEAR=2015 and FISCAL_WEEK between 39 and 44
group by line ,Cat_key
having count(*) =6
) a
join 
(
select cat_key, pred_RR from RR_error_AD_All_wks_6WK_MA_post2wks
where FISCAL_WEEK=38 and FISCAL_YEAR=2015
) b
on a.cat_key=b.cat_key
join
(select distinct line ,MD_TAKEN_flag from Sac_returns_base_data
where FISCAL_YEAR=2015 and FISCAL_WEEK =41) c
on a.Line=c.line
join
(select Cat_key ,sum(case when MD_PERIOD_FLAG=0 then rr end) as Reg_RR
,sum(case when MD_PERIOD_FLAG=1 then rr end) as MD_RR  
from Sac_Overall_RR group by Cat_key
) d
on a.cat_key=d.cat_key
where gross_sales_units>0
