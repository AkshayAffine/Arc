-------------------==================== Final AD (including derived variables) =========-----------------------------
Drop table Final_master_AD_1;

select MERCHANDISE_KEY,
	LOCATION_KEY,
	cast(FISCAL_YEAR as bigint) FISCAL_YEAR,
	cast(FISCAL_WEEK as bigint) FISCAL_WEEK,
	cast(NET_SALES_UNITS as int) NET_SALES_UNITS,
	cast(NET_SALES_DOLLARS as decimal(38,2)) NET_SALES_DOLLARS,
	cast(GROSS_SALES_UNITS as int) GROSS_SALES_UNITS,
	cast(GROSS_SALES_DOLLARS as decimal(38,2)) GROSS_SALES_DOLLARS,
	cast(POS_SALES_UNITS as int) POS_SALES_UNITS,
	cast(POS_SALES_DOLLARS as decimal(38,2)) POS_SALES_DOLLARS,
	cast(EOP_INVENTORY_UNITS as int) EOP_INVENTORY_UNITS,
	cast(EOP_ON_ORDER_UNITS as int) EOP_ON_ORDER_UNITS,
	cast(STORE_NUM_WITH_INVENTORY as int) STORE_NUM_WITH_INVENTORY,
	cast(STORE_NUM_WITH_ONORDER as int) STORE_NUM_WITH_ONORDER,
	cast(CURRENT_RETAIL as decimal(38,2)) CURRENT_RETAIL,
	cast(CURRENT_INVENTORY_PRICE as decimal(38,2)) CURRENT_INVENTORY_PRICE,
	cast(UNIT_COST as decimal(38,2)) UNIT_COST,
	cast(FULL_PRICE as decimal(38,2)) FULL_PRICE,
	cast(case when MD_TAKEN_flag is not null then max(cast(md_price as decimal(38,2))) over (partition by merchandise_key,md_taken_flag)
		else md_price end as decimal(38,2)) Running_Regular_price,		---Current retail prior week markdown applied
	cast(case when MD_TAKEN_flag is not null then max(cast(md_price as decimal(38,2))) over (partition by merchandise_key,case when md_taken_flag>0 then 0 end)
		else md_price end as decimal(38,2)) Regular_price,				---Current retail before markdowns applied
	cast(Final_price as decimal(38,2)) Final_price,
	cast(PROMO_PRICE as decimal(38,2)) PROMO_PRICE,
	PROMO_DESC,
	cast(PRICE_POINT as decimal(38,2)) PRICE_POINT,
	promo_discount,
	MD_TAKEN_flag,
	MD_TAKEN_PERIOD,
	cast(md_price as decimal(38,2)) md_price,
	(cast(case when MD_TAKEN_flag is not null then max(cast(md_price as decimal(38,2))) over (partition by merchandise_key,md_taken_flag)
		else md_price end as decimal(38,2)) -price_point)*100.0/(cast(case when MD_TAKEN_flag is not null then max(cast(md_price as decimal(38,2))) over (partition by merchandise_key,md_taken_flag)
		else md_price end as decimal(38,2)))
	md_discount_run,		----Based on running regular price i.e. week prior markdown applied
	(cast(case when MD_TAKEN_flag is not null then max(cast(md_price as decimal(38,2))) over (partition by merchandise_key,case when md_taken_flag>0 then 0 end)
		else md_price end as decimal(38,2)) -price_point)*100.0/(cast(case when MD_TAKEN_flag is not null then max(cast(md_price as decimal(38,2))) over (partition by merchandise_key,case when md_taken_flag>0 then 0 end)
		else md_price end as decimal(38,2)))
	md_discount,			---Based on regular price considering before markdowns current retail
	Pricing_Group,
	cast(Exit_date as bigint) Exit_date,
	cast(no_wk_business as int) no_wk_business,
	Brand,
	Brand_key,
	Brand_Desc,
	Dept,
	Dept_key,
	Dept_Desc,
	Cat,
	Cat_key,
	Cat_Desc,
	Line,
	Line_key,
	Line_Desc,
	INVE_MERCHANDISE_KEY,
	cast(INV_FISCAL_YEAR as bigint) INV_FISCAL_YEAR,
	cast(INV_FISCAL_WEEK as bigint) INV_FISCAL_WEEK,
	cast(EOP_DC_Inventory_Units as int) EOP_DC_Inventory_Units,
	cast(EOP_DC_On_Order_Units as int) EOP_DC_On_Order_Units
into Final_master_AD_1
from
	(select MERCHANDISE_KEY,
		LOCATION_KEY,
		FISCAL_YEAR,
		FISCAL_WEEK,
		NET_SALES_UNITS,
		NET_SALES_DOLLARS,
		GROSS_SALES_UNITS,
		GROSS_SALES_DOLLARS,
		POS_SALES_UNITS,
		POS_SALES_DOLLARS,
		EOP_INVENTORY_UNITS,
		EOP_ON_ORDER_UNITS,
		STORE_NUM_WITH_INVENTORY,
		STORE_NUM_WITH_ONORDER,
		CURRENT_RETAIL,
		CURRENT_INVENTORY_PRICE,
		UNIT_COST,
		FULL_PRICE,
		case when PROMO_PRICE is not null then PROMO_PRICE
				when PROMO_PRICE is null and price_point is not null then PRICE_POINT
				else CURRENT_RETAIL end Final_price,		---Final Selling price of merchandise
		PROMO_PRICE,
		PROMO_DESC,
		PRICE_POINT,
		case when cast(promo_price as float)>cast(CURRENT_RETAIL as float) 
				then (cast(full_price as float)-cast(PROMO_PRICE as float))*100.0/cast(full_price as float)
				else (cast(CURRENT_RETAIL as float)-cast(PROMO_PRICE as float))*100.0/cast(CURRENT_RETAIL as float)
			end promo_discount,		--Discount given on promo
		MD_TAKEN_flag,
		MD_TAKEN_PERIOD,
		coalesce(case when PRICE_POINT is null 
				then lag(current_retail,1,CURRENT_RETAIL) over(partition by merchandise_key order by cast(fiscal_year as int),cast(fiscal_week as int))
			else lag(current_retail,1) over(partition by merchandise_key,md_taken_flag order by cast(fiscal_year as int),cast(fiscal_week as int))
			end,lag(current_retail) over(partition by merchandise_key order by cast(fiscal_year as int),cast(fiscal_week as int)))
			md_price,		--Price after markdown applied
			
		/* (cast(coalesce(case when PRICE_POINT is null 
				then lag(current_retail,1,CURRENT_RETAIL) over(partition by merchandise_key order by cast(fiscal_year as int),cast(fiscal_week as int))
			else lag(current_retail,1) over(partition by merchandise_key,md_taken_flag order by cast(fiscal_year as int),cast(fiscal_week as int))
			end,lag(current_retail) over(partition by merchandise_key order by cast(fiscal_year as int),cast(fiscal_week as int))) as float) -cast(price_point as float))*100.0/
			cast(coalesce(case when PRICE_POINT is null 
				then lag(current_retail,1,CURRENT_RETAIL) over(partition by merchandise_key order by cast(fiscal_year as int),cast(fiscal_week as int))
			else lag(current_retail,1) over(partition by merchandise_key,md_taken_flag order by cast(fiscal_year as int),cast(fiscal_week as int))
			end,lag(current_retail) over(partition by merchandise_key order by cast(fiscal_year as int),cast(fiscal_week as int))) as float)
			md_discount, */
		ATTRIBUTE1 Pricing_Group,
		ATTRIBUTE3 Exit_Date,
		ATTRIBUTE3_NUMBER no_wk_business,
		HIERARCHY1_ID Brand,
		HIERARCHY1_KEY Brand_key,
		HIERARCHY1_DESC Brand_Desc,
		HIERARCHY3_ID Dept,
		HIERARCHY3_KEY Dept_key,
		HIERARCHY3_DESC Dept_Desc,
		HIERARCHY4_ID Cat,
		HIERARCHY4_KEY Cat_key,
		HIERARCHY4_DESC Cat_Desc,
		HIERARCHY7_ID Line,
		HIERARCHY7_KEY Line_key,
		HIERARCHY7_DESC Line_Desc,
		INVE_MERCHANDISE_KEY,
		INV_FISCAL_YEAR,
		INV_FISCAL_WEEK,
		EOP_DC_Inventory_Units,
		EOP_DC_On_Order_Units
	from FINAL_MASTER_TABLE
	) a
	
	
	
	
	
----------Final_Master_AD_2


select *
		,case when no_wk_business>cnt then    ---Launch date calculation
				concat(left(max_period,4)-(floor((no_wk_business-right(max_period,2))*1.0/52.0)+1)
						,floor(52-(52*(((no_wk_business-right(max_period,2))*1.0/52.0)-(floor((no_wk_business-right(max_period,2))*1.0/52.0))))))
			when no_wk_business<=cnt then min(concat(FISCAL_YEAR,case when len(fiscal_week)=1 then 0 end,fiscal_week)) over(partition by merchandise_key)
		end launch_date
		---MD flag for first and furhter
		,case when md_taken_flag=1 and coalesce(PROMO_PRICE,0)<>Final_price then 'First'
			when md_taken_flag>1 and inventory>((max(case when md_taken_flag=1 and base_md=1 then inventory+net_sales_units end) over(partition by merchandise_key))*0.02) then 'Further'
			end MD_FLag
into final_master_AD_2
from
(
select distinct *,coalesce(EOP_DC_Inventory_Units,0) + coalesce(EOP_INVENTORY_UNITS,0) + coalesce(EOP_ON_ORDER_UNITS,0) inventory
	,count(*) over(partition by merchandise_key) cnt	
	,ROW_NUMBER() over(partition by merchandise_key order by fiscal_year,fiscal_week) no_sales_wk	
	,max(concat(FISCAL_YEAR,case when len(fiscal_week)=1 then 0 end,fiscal_week)) over(partition by merchandise_key) max_period
	,row_number() over(partition by merchandise_key,md_taken_flag order by fiscal_year,fiscal_week) base_md
from Final_master_AD_1		
)a
order by FISCAL_YEAR,FISCAL_WEEK
