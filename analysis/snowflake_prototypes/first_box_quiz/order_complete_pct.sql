/*** Snowflake prototype dashboard: https://app.snowflake.com/us-east-1/lna65058/first-box-dashboard-includes-any-visitor-that-saw-the-homepage-with-fbq-dZ6KnqQC4 ****/
/**** FBQ Order Complete Percent | Number of Order Complete / Number of FBQ CTA Clicked ****/

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

,order_complete as (
    select
        fbq_flow.visit_id
        ,count(event_order_complete.visit_id) as order_complete_count
    from fbq_flow
        inner join event_order_complete on fbq_flow.visit_id = event_order_complete.visit_id
    group by 1
)
   
select
    fbq_flow.visit_date
    ,count(distinct fbq_flow.visit_id) as fbq_count
    ,count(distinct order_complete.visit_id)::float/count(distinct fbq_flow.visit_id)::float as "Pct FBQ Order Complete"
from fbq_flow
    left join order_complete on fbq_flow.visit_id = order_complete.visit_id
where fbq_flow.is_guest_user = :is_guest
group by 1
order by 1;
