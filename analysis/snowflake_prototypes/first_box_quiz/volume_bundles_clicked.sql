/*** Snowflake prototype dashboard: https://app.snowflake.com/us-east-1/lna65058/first-box-dashboard-includes-any-visitor-that-saw-the-homepage-with-fbq-dZ6KnqQC4 ****/
/**** Volume of Bundles Clicked - Both Customized and Selected ****/

with
invalid_experiments as (
    select
        visit_id
        ,experiment_token
        ,count(distinct experiment_variant) as variant_count
    from experiments_by_event_id
    where experiment_token = :experiment_token
    group by 1,2
    having count(distinct experiment_variant) > 1
),
valid_experiments as (
    select distinct
        visit_id
        ,experiment_token
        ,experiment_variant
    from experiments_by_event_id
    where visit_id not in (select visit_id from invalid_experiments)
        and experiment_token = :experiment_token
),
members as (
    select
        user_id
        ,min(created_at) as first_subscription_date
        ,count(subscription_id) as subscription_count
    from dim_subscription
    where dbt_valid_to is null
    group by 1
)

,traffic_to_fbq as (
    select
        visit_id
        ,count(event_id) as event_count
    from fact_event_pageview
    where parse_url(url):path::text = 'first-box'
        and occurred_at >= '2021-08-25'
    group by 1
)

,fbq_flow as (
    select
        fact_visit.visit_id
        ,fact_visit.user_id
        ,case
            when dim_user.email like 'TEMPORARY%CROWDCOW.COM%' then TRUE
            when dim_user.email is null then FALSE
            else FALSE
         end as is_guest_user
        ,members.user_id is not null as is_member
        ,date(convert_timezone('UTC','America/Los_Angeles',fact_visit.visited_at)) as visit_date
        ,valid_experiments.experiment_token
        ,valid_experiments.experiment_variant
    from fact_visit
        inner join valid_experiments on fact_visit.visit_id = valid_experiments.visit_id
        left join dim_user on fact_visit.user_id = dim_user.user_id
            and dim_user.dbt_valid_to is null
        left join members on fact_visit.user_id = members.user_id
    where convert_timezone('UTC','America/Los_Angeles',fact_visit.visited_at) = :daterange
        and fact_visit.visit_id in (select visit_id from traffic_to_fbq)
        and not fact_visit.is_bot
        and not fact_visit.is_internal_traffic
        and (utm_medium <> 'FIELD-MARKETING' or utm_medium is null)
        and (members.user_id is null or members.first_subscription_date >= fact_visit.visited_at)
)

,clicked_on_bundle as (
    select
        fbq_flow.visit_id
        ,count(event_quiz_nav_purchase_bundle.visit_id) as cnt
        ,event_quiz_nav_purchase_bundle.bid_item_key
        , fbq_flow.visit_date
    from fbq_flow
        inner join event_quiz_nav_purchase_bundle on fbq_flow.visit_id = event_quiz_nav_purchase_bundle.visit_id
    group by 1, 3, 4
)


,bid_items_from_bundle_select as (
  select dim_bid_item.bid_item_name as bundle_name
         , dim_bid_item.bid_item_key
         , clicked_on_bundle.visit_id
  from clicked_on_bundle
       inner join dim_bid_item on dim_bid_item.bid_item_key = clicked_on_bundle.bid_item_key
)

,clicked_customize_bundle as (
    select
        fbq_flow.visit_id
        ,count(event_quiz_nav_customize_bundle.visit_id) as cnt
        , fbq_flow.visit_date
        , event_quiz_nav_customize_bundle.bid_item_key
    from fbq_flow
        inner join event_quiz_nav_customize_bundle on fbq_flow.visit_id = event_quiz_nav_customize_bundle.visit_id
    group by 1, 3, 4
)

,bid_items_from_customize_select as (
  select dim_bid_item.bid_item_name as bundle_name
         , clicked_customize_bundle.visit_id
         , dim_bid_item.bid_item_key
  from clicked_customize_bundle
       inner join dim_bid_item on dim_bid_item.bid_item_key = clicked_customize_bundle.bid_item_key
)
   
select
    count(distinct clicked_on_bundle.visit_id)
    , 'Selected Bundle' as visitor_action
    ,visit_date
    ,bid_items_from_bundle_select.bundle_name
from clicked_on_bundle
    inner join event_quiz_nav_purchase_bundle on clicked_on_bundle.visit_id = event_quiz_nav_purchase_bundle.visit_id
    inner join bid_items_from_bundle_select on event_quiz_nav_purchase_bundle.bid_item_key = bid_items_from_bundle_select.bid_item_key
where
    fbq_flow.is_guest_user = :is_guest
group by 2, 3, 4


union

select
    count(distinct clicked_customize_bundle.visit_id)
    , 'Selected Customize' as visitor_action
    ,clicked_customize_bundle.visit_date
    ,bid_items_from_customize_select.bundle_name
from clicked_customize_bundle
    inner join event_quiz_nav_purchase_bundle on clicked_customize_bundle.visit_id = event_quiz_nav_purchase_bundle.visit_id
    inner join bid_items_from_customize_select on event_quiz_nav_purchase_bundle.bid_item_key = bid_items_from_customize_select.bid_item_key
where
    fbq_flow.is_guest_user = :is_guest
group by 2, 3, 4
order by 3, 4, 2
