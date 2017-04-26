

-------------------------------------------------# ITEMS------------------------------------------------------

SELECT ITEM_TAB.*,
CAL_START.[FISCAL_YEAR] AS YEAR_START,CAL_START.[FISCAL_WEEK] AS WEEK_START,
CAL_END.[FISCAL_YEAR] AS YEAR_END,CAL_END.[FISCAL_WEEK] AS WEEK_END
INTO ITEMS_TABLE_USE
FROM
	(
	-------#ITEMS DATA WITH WEEKEND DATES----
	SELECT *,dateAdd(dd,7-DATEPART(dw,CRT_FIRST_RECEIPT_DATE),CRT_FIRST_RECEIPT_DATE) AS WKND_FIRST_RECEIPT_DATE,
	dateAdd(dd,7-DATEPART(dw, CRT_LAST_RECEIPT_DATE), CRT_LAST_RECEIPT_DATE) AS WKND_LAST_RECEIPT_DATE
	FROM (
		select *,cast([FIRST_RECEIPT_DATE] AS DATE) CRT_FIRST_RECEIPT_DATE,cast([LAST_RECEIPT_DATE] AS DATE) CRT_LAST_RECEIPT_DATE
		from [dbo].[items]
		WHERE LOCATION_KEY= 'AA'
		 )A
	---------
	) ITEM_TAB

LEFT JOIN 
	(SELECT *,CAST(CALENDAR_DATE AS DATE) AS CRT_CALENDAR_DATE
	FROM [dbo].[cal]
	) CAL_START
ON ITEM_TAB.WKND_FIRST_RECEIPT_DATE=CAL_START.CRT_CALENDAR_DATE

LEFT JOIN 
	(SELECT *,CAST(CALENDAR_DATE AS DATE) AS CRT_CALENDAR_DATE
	FROM [dbo].[cal]
	) CAL_END
ON ITEM_TAB.WKND_LAST_RECEIPT_DATE=CAL_END.CRT_CALENDAR_DATE



------------------------------------------------------#MD TAKEN TABLE----------------------------------------------

DROP TABLE MD_TAKEN_CHANGED

SELECT MD_TAKEN_TAB.*,
CAL_START.[FISCAL_YEAR] AS YEAR_START,CAL_START.[FISCAL_WEEK] AS WEEK_START,
CAL_END.[FISCAL_YEAR] AS YEAR_END,CAL_END.[FISCAL_WEEK] AS WEEK_END
INTO MD_TAKEN_CHANGED
FROM
(
	select *,dateAdd(dd,7-DATEPART(dw,CRT_EFFECTIVE_DATE),CRT_EFFECTIVE_DATE) as WKND_MK_START_DATE,
	dateAdd(dd,7-DATEPART(dw,END_DATE),END_DATE) AS WKND_MK_END_DATE FROM 
	(
	------#TAKING LEAD FOR END DATE OF A MARKDOWN--
	SELECT *,
	LEAD(EFFECTIVE_DATE,1,cast(GETDATE() AS DATE)) OVER (PARTITION BY MERCHANDISE_KEY,LOCATION_KEY ORDER BY EFFECTIVE_DATE) AS END_DATE
	  FROM ( SELECT *,CAST(EFFECTIVE_DATE AS DATE) AS CRT_EFFECTIVE_DATE
		  FROM [dbo].[mdtaken]
		  WHERE LOCATION_KEY = 'AA'
		  ) A
	)A
	) MD_TAKEN_TAB

LEFT JOIN 
	(SELECT *,CAST(EOP_CALENDAR_DATE AS DATE) AS CRT_CALENDAR_DATE
	FROM [dbo].[cal]
	) CAL_START
ON MD_TAKEN_TAB.WKND_MK_START_DATE=CAL_START.CRT_CALENDAR_DATE

LEFT JOIN 
	(SELECT *,CAST(EOP_CALENDAR_DATE AS DATE) AS CRT_CALENDAR_DATE
	FROM [dbo].[cal]
	) CAL_END
ON MD_TAKEN_TAB.WKND_MK_END_DATE=CAL_END.CRT_CALENDAR_DATE
ORDER BY MERCHANDISE_KEY,EFFECTIVE_DATE


---CHANGING THE WEEKEND NUMBER FOR MERCHANIDSE WITH MORE TAHN ONE MARKDOWN---

SELECT *,
CASE WHEN KEY_NUM=KEYS THEN WEEK_END
ELSE WEEK_END-1
END AS CHNGD_WEEK_END 
INTO MD_TAKEN_FINAL
FROM 
	(
	SELECT A.*,ROW_NUMBER() over (partition by A.MERCHANDISE_KEY ORDER BY A.EFFECTIVE_DATE) AS KEY_NUM,B.KEYS
	 FROM MD_TAKEN_CHANGED A
		 JOIN (SELECT DISTINCT MERCHANDISE_KEY,COUNT(DISTINCT EFFECTIVE_DATE) AS KEYS
			   FROM MD_TAKEN_CHANGED
			   GROUP BY MERCHANDISE_KEY) b
	 on A.MERCHANDISE_KEY=B.MERCHANDISE_KEY
	 )A


 --------------------------------------------FINAL PROMO TABLE-----------------------------------------
 --------------------------------PROMO PART 1---------------------------

SELECT PROMO_TAB.*,
CAL_START.[FISCAL_YEAR] AS YEAR_START,CAL_START.[FISCAL_WEEK] AS WEEK_START,
CAL_END.[FISCAL_YEAR] AS YEAR_END,CAL_END.[FISCAL_WEEK] AS WEEK_END
INTO PROMO_TABLE_USE
FROM
(
-------#PROMO DATA WITH WEEKEND DATES----
	SELECT *,dateAdd(dd,7-DATEPART(dw,CRT_PROMO_START_DATE),CRT_PROMO_START_DATE) AS WKND_PROMO_START_DATE,
	dateAdd(dd,7-DATEPART(dw, CRT_PROMO_END_DATE), CRT_PROMO_END_DATE) AS WKND_PROMO_END_DATE
	FROM (
			select *,cast(PROMO_START_DATE AS DATE) CRT_PROMO_START_DATE,cast(PROMO_END_DATE AS DATE) CRT_PROMO_END_DATE
			from [dbo].[promo]
			WHERE LOCATION_KEY= 'AA'
		 )A
	---------
	) PROMO_TAB

LEFT JOIN 
	(SELECT *,CAST(CALENDAR_DATE AS DATE) AS CRT_CALENDAR_DATE
	FROM [dbo].[cal]
	) CAL_START
ON PROMO_TAB.WKND_PROMO_START_DATE=CAL_START.CRT_CALENDAR_DATE

LEFT JOIN 
	(SELECT *,CAST(CALENDAR_DATE AS DATE) AS CRT_CALENDAR_DATE
	FROM [dbo].[cal]
	) CAL_END
ON PROMO_TAB.WKND_PROMO_END_DATE=CAL_END.CRT_CALENDAR_DATE
-----110876


-----------------------------------------PROMO PART-2---------------------------------------------

select YEAR_START,fw,MERCHANDISE_KEY
	,sum(price*no_days)/sum(no_days) promo_price
	,max(promo_desc) max_promo_desc
	,min(promo_desc) min_promo_desc
into promo_lookup
from
	(select a.*,b.fiscal_week fw
		,case when b.fiscal_week=WEEK_START then no_days_start
			when b.fiscal_week=WEEK_END then no_days_end
			when b.fiscal_week<>WEEK_START and b.fiscal_week<>week_end then 7
			end no_days
		from
			(
			select distinct MERCHANDISE_KEY,YEAR_START,week_start,WEEK_END
				,case when WKND_PROMO_START_DATE<>WKND_PROMO_END_DATE then datediff(day,wknd_promo_end_date,crt_promo_end_date) +7
					when WKND_PROMO_START_DATE=WKND_PROMO_END_DATE then datediff(day,crt_promo_start_date,crt_promo_end_date)+1 end no_days_end
				,case when WKND_PROMO_START_DATE<>WKND_PROMO_END_DATE then datediff(day,crt_promo_start_date,WKND_PROMO_START_DATE) +1
					when WKND_PROMO_START_DATE=WKND_PROMO_END_DATE then datediff(day,crt_promo_start_date,crt_promo_end_date)+1 end no_days_start
				,count(distinct promo_key) dr
				,max(cast(PROMO_PRICE as float)) max_price
				,avg(cast(promo_price as float)) price
				,max(promo_desc) promo_desc
				,min(promo_desc) promo_desc_min
			from promo_table_use a
			group by MERCHANDISE_KEY,YEAR_START,WEEK_end,week_start
				,case when WKND_PROMO_START_DATE<>WKND_PROMO_END_DATE then datediff(day,wknd_promo_end_date,crt_promo_end_date) +7
					when WKND_PROMO_START_DATE=WKND_PROMO_END_DATE then datediff(day,crt_promo_start_date,crt_promo_end_date)+1 end
				,case when WKND_PROMO_START_DATE<>WKND_PROMO_END_DATE then datediff(day,crt_promo_start_date,wknd_promo_start_date) +1
					when WKND_PROMO_START_DATE=WKND_PROMO_END_DATE then datediff(day,crt_promo_start_date,crt_promo_end_date)+1 end
			) a
			left join (select distinct fiscal_week from cal) b
				on cast(b.fiscal_week as int) between cast(coalesce(a.week_start,a.week_end) as int) and cast(a.week_end as int)
			--order by MERCHANDISE_KEY,YEAR_START,WEEK_end,week_start
	) s
group by YEAR_START,fw,MERCHANDISE_KEY
order by MERCHANDISE_KEY,YEAR_START,fw



-------------------------------------------------------------FINAL MASTER TABLE CREATION CODE------------------------------------


SELECT A.*,B.*,
C.ATTRIBUTE1,C.ATTRIBUTE3,C.ATTRIBUTE3_NUMBER,
E.PRICE_POINT,G.UNIT_COST,G.FULL_PRICE,F.PROMO_PRICE,F.PROMO_DESC,
D.MERCHANDISE_KEY AS INVE_MERCHANDISE_KEY,D.FISCAL_YEAR AS INV_FISCAL_YEAR,D.FISCAL_WEEK AS INV_FISCAL_WEEK,
D.EOP_DC_Inventory_Units,D.EOP_DC_On_Order_Units
INTO FINAL_MASTER_TABLE
FROM (select * from sales WHERE LOCATION_KEY = 'AA')  A --------SALES TABLE-----
LEFT JOIN (SELECT DISTINCT [HIERARCHY1_ID],[HIERARCHY1_KEY],[HIERARCHY1_DESC],
             [HIERARCHY3_ID],[HIERARCHY3_KEY],[HIERARCHY3_DESC],
			 [HIERARCHY4_ID],[HIERARCHY4_KEY],[HIERARCHY4_DESC],
			 [HIERARCHY7_ID],[HIERARCHY7_KEY],[HIERARCHY7_DESC]
			 FROM [dbo].[mh]
			 )B
ON A.MERCHANDISE_KEY=B.HIERARCHY7_KEY
LEFT JOIN 
        (SELECT * FROM [dbo].[items_cda] WHERE LOCATION_KEY = 'AA')C   ------------------ITEMS_CDA-------------------
ON A.MERCHANDISE_KEY=C.MERCHANDISE_KEY

FULL JOIN [dbo].[dci] D  --------------DC_INVENTORY----------
on CONCAT(a.MERCHANDISE_KEY,A.FISCAL_YEAR,A.FISCAL_WEEK)=CONCAT(D.MERCHANDISE_KEY,D.FISCAL_YEAR,D.FISCAL_WEEK)

left join MD_TAKEN_FINAL e  ---------------MD_TAKEN--------------------
on A.MERCHANDISE_KEY=E.MERCHANDISE_KEY 
AND cast(concat(a.fiscal_year,case when len(a.FISCAL_WEEK)=1 then concat('0',a.FISCAL_WEEK) else a.FISCAL_WEEK end) as bigint) between 
cast(concat(E.year_start,case when len(E.week_start)=1 then concat('0',E.week_start) else E.week_start end) as bigint)
and cast(concat(E.year_end,case when len(E.chngd_week_end)=1 then concat('0',E.chngd_week_end) else E.chngd_week_end end) as bigint)

LEFT JOIN (SELECT *,
			CASE WHEN max_promo_desc=min_promo_desc THEN max_promo_desc
			ELSE CONCAT(MAX_PROMO_DESC,'; ',min_promo_desc)
			END AS promo_desc
			FROM promo_lookup) f       ------------------------------PROMO TABLE------------
on A.MERCHANDISE_KEY=F.MERCHANDISE_KEY
AND A.fiscal_year=F.YEAR_START
AND CAST(A.FISCAL_WEEK AS INT) = CAST(F.FW AS INT)

LEFT JOIN (SELECT * FROM [dbo].[items] WHERE LOCATION_KEY = 'AA') G  -----------------------------items table------------
ON A.MERCHANDISE_KEY=G.MERCHANDISE_KEY

        
---2397963
