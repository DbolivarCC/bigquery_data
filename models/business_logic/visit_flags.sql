{{
  config(
        snowflake_warehouse = 'TRANSFORMING_M'
    )
}}

with

visits as ( select * from {{ ref('visits') }} ),
suspicious_ips as ( select * from {{ ref('stg_cc__suspicious_ips') }} ),
subscribed as ( select * from {{ ref('stg_cc__event_subscribed') }} ),
sign_up as ( select * from {{ ref('stg_cc__event_sign_up') }} ),
order_complete as ( select * from {{ ref('stg_cc__event_order_complete') }} ),
unsubscribed as ( select * from {{ ref('stg_cc__event_unsubscribed') }} ),
orders as ( select * from {{ ref('stg_cc__orders') }} ),
subscriptions as ( select * from {{ ref('stg_cc__subscriptions') }} ),
users as ( select * from {{ ref('stg_cc__users') }} ),
pcp_impressions as (select * from {{ ref('stg_cc__event_pcp_impression') }} ),
pcp_impression_clicks as (select * from {{ref('stg_cc__event_pcp_impression_click') }} ),
pdp_product_add_to_cart as (select * from {{ref('stg_cc__event_pdp_product_add_to_cart') }} ),
viewed_pdp as (select * from {{ ref('stg_cc__event_viewed_product') }} ),

subscription_visits as (
    select 
         subscribed.visit_id
        ,count(distinct subscribed.subscription_id) as subscribe_count
        ,count(distinct unsubscribed.subscription_id) as unsubscribe_count
    from subscribed
        left join unsubscribed on (subscribed.visit_id = unsubscribed.visit_id and subscribed.subscription_id = unsubscribed.subscription_id)
    group by 1
    having count(distinct subscribed.subscription_id) - count(distinct unsubscribed.subscription_id) > 0
),

user_first_order as (
    select
        user_id
        ,min(order_paid_at_utc) as first_order_date
    from orders
    where order_paid_at_utc is not null
    group by 1
),

user_first_subscription as (
    select 
        user_id
        ,min(subscription_created_at_utc) as first_subscription_date
    from subscriptions
    group by 1
),

user_account_created as (
    select
        user_id
        ,min(created_at_utc) as first_creation_date
    from users
    group by 1
),

user_signed_up as (
    select
        visit_id
        ,count(distinct user_id) as total_signed_up
    from sign_up
    group by 1
),

order_completed as (
    select
        visit_id
        ,count(distinct order_id) as total_order_count
    from order_complete
    group by 1
),

employee_user as (
    select distinct
        user_id
    from users
    where user_type = 'EMPLOYEE'
),

pcp_impression_visits as ( 
    select pcp_impressions.visit_id
    , count(distinct pcp_impressions.event_id) as pcp_impressions_count
    from pcp_impressions
    group by 1
), 

pcp_impression_click_visits as ( 
    select 
        pcp_impression_clicks.visit_id 
        ,count(distinct pcp_impression_clicks.event_id) as pcp_impression_clicks_count
    from pcp_impression_clicks
    group by 1
),

pdp_product_add_to_cart_visits as ( 
    select 
        pdp_product_add_to_cart.visit_id
        ,count(distinct pdp_product_add_to_cart.event_id) as pdp_product_add_to_cart_count
    from pdp_product_add_to_cart
    group by 1
),

viewed_pdp_visits as ( 
    select 
        viewed_pdp.visit_id
        ,count(distinct viewed_pdp.event_id) as pdp_views_count
    from viewed_pdp
    group by 1
),

add_flags as (
    select
        visits.visit_id

        ,visits.visit_landing_page_host = 'WWW.CROWDCOW.COM' 
            and visits.visit_landing_page_path in ('/','/L') as is_homepage_landing

        ,suspicious_ips.visit_ip is not null
            or visits.visit_user_agent like any ('%BOT%','%CRAWL%','%LIBRATO%','%TWILIOPROXY%','%YAHOOMAILPROXY%','%SCOUTURLMONITOR%','%FULLCONTACT%','%IMGIX%','%BUCK%')
            or (visits.visit_ip is null and visits.visit_user_agent is null) as is_bot

        ,visits.visit_ip in ('66.171.181.219', '127.0.0.1') or employee_user.user_id as is_internal_traffic
        ,user_first_order.user_id is not null and user_first_order.first_order_date < visits.started_at_utc as has_previous_order
        ,user_first_subscription.user_id is not null and user_first_subscription.first_subscription_date < visits.started_at_utc as has_previous_subscription
        ,user_account_created.user_id is not null and user_account_created.first_creation_date < visits.started_at_utc as had_account_created
        ,subscription_visits.visit_id is not null as did_subscribe
        ,user_signed_up.visit_id is not null as did_sign_up
        ,order_completed.visit_id is not null as did_complete_order
        ,pcp_impression_visits.pcp_impressions_count
        ,pcp_impression_click_visits.pcp_impression_clicks_count
        ,pdp_product_add_to_cart_visits.pdp_product_add_to_cart_count
        ,viewed_pdp_visits.pdp_views_count

    from visits
        left join suspicious_ips on visits.visit_ip = suspicious_ips.visit_ip
        left join subscription_visits on visits.visit_id = subscription_visits.visit_id
        left join user_first_order on visits.user_id = user_first_order.user_id
        left join user_first_subscription on visits.user_id = user_first_subscription.user_id
        left join user_account_created on visits.user_id = user_account_created.user_id
        left join user_signed_up on visits.visit_id = user_signed_up.visit_id
        left join order_completed on visits.visit_id = order_completed.visit_id
        left join employee_user on visits.user_id = employee_user.user_id
        left join pcp_impression_visits on visits.visit_id = pcp_impression_visits.visit_id
        left join pcp_impression_click_visits on visits.visit_id = pcp_impression_click_visits.visit_id 
        left join pdp_product_add_to_cart_visits on visits.visit_id = pdp_product_add_to_cart_visits.visit_id
        left join viewed_pdp_visits on visits.visit_id = viewed_pdp_visits.visit_id
)

select * from add_flags
