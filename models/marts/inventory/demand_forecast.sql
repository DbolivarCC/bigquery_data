with

/**** AWS generated forecasts prior to 2022-06-14 and those forecast values are kept for historical reporting purposes ***/
/**** Fountain9 generates forecasts from 2022-06-14 going forward ***/
aws as ( select * from {{ ref('stg_forecasting__cat_subcat_daily') }} where forecast_date < '2022-06-14' )
,f9 as ( select * from {{ ref('stg_fountain9__demand_forecasts') }} )

,union_forecasts as (
    select
        forecast_id
        ,forecast_date
        ,fc_id
        ,category
        ,sub_category
        ,cut_id
        ,round(p50,2) as forecasted_sales
    from aws

    union all

    select
        forecast_id
        ,forecast_date
        ,fc_id
        ,category
        
        /*** String cleaning is required since F9 changes the values of the data we send to them ***/
        /*** this was causing a misatch when trying to join on sub_category since we use this as a part of our "key" ***/
        ,case
            when sub_category = 'ORGANIC 100% GRASS FED' then 'ORGANIC, 100% GRASS FED'
            when sub_category = 'NOT SPECIFIED' then null
            else sub_category
        end as sub_category
        
        ,cut_id
        ,forecasted_sales
    from f9
)

select
    {{ dbt_utils.surrogate_key(['forecast_date','fc_id','category','sub_category','cut_id']) }} as forecast_combined_id
    ,*
from union_forecasts
