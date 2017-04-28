select MERCHANDISE_KEY,
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
PROMO_PRICE,
PROMO_DESC,
PRICE_POINT,
case when cast(promo_price as float)>cast(CURRENT_RETAIL as float) 
		then (cast(full_price as float)-cast(PROMO_PRICE as float))*100.0/cast(full_price as float)
		else (cast(CURRENT_RETAIL as float)-cast(PROMO_PRICE as float))*100.0/cast(CURRENT_RETAIL as float)
	end promo_discount,
MD_TAKEN_flag,
MD_TAKEN_PERIOD,
coalesce(case when PRICE_POINT is null 
		then lag(current_retail,1,CURRENT_RETAIL) over(partition by merchandise_key order by cast(fiscal_year as int),cast(fiscal_week as int))
	else lag(current_retail,1) over(partition by merchandise_key,md_taken_flag order by cast(fiscal_year as int),cast(fiscal_week as int))
	end,lag(current_retail) over(partition by merchandise_key order by cast(fiscal_year as int),cast(fiscal_week as int)))
	md_price,
(cast(coalesce(case when PRICE_POINT is null 
		then lag(current_retail,1,CURRENT_RETAIL) over(partition by merchandise_key order by cast(fiscal_year as int),cast(fiscal_week as int))
	else lag(current_retail,1) over(partition by merchandise_key,md_taken_flag order by cast(fiscal_year as int),cast(fiscal_week as int))
	end,lag(current_retail) over(partition by merchandise_key order by cast(fiscal_year as int),cast(fiscal_week as int))) as float) -cast(price_point as float))*100.0/
	cast(coalesce(case when PRICE_POINT is null 
		then lag(current_retail,1,CURRENT_RETAIL) over(partition by merchandise_key order by cast(fiscal_year as int),cast(fiscal_week as int))
	else lag(current_retail,1) over(partition by merchandise_key,md_taken_flag order by cast(fiscal_year as int),cast(fiscal_week as int))
	end,lag(current_retail) over(partition by merchandise_key order by cast(fiscal_year as int),cast(fiscal_week as int))) as float)
	md_discount,
ATTRIBUTE1 Pricing_Group,
ATTRIBUTE3 Exit_Group,
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
into Final_master_AD_1
from FINAL_MASTER_TABLE