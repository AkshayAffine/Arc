----Creating PROMO lookup table
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
