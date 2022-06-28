with

memberships as (select * from {{ ref('stg_cc__subscriptions') }})
,orders as (select * from {{ ref('orders') }})

,order_count as (
    select
        subscription_id
        ,count_if(not is_cancelled_order and is_paid_order and is_membership_order and sysdate()::date - order_paid_at_utc::date <= 90) as total_active_order_count
    from orders
    group by 1
)

,membership_joins as (
    select
        memberships.*
        ,order_count.subscription_id is not null and order_count.total_active_order_count > 0 as is_active_membership
    from memberships
        left join order_count on memberships.subscription_id = order_count.subscription_id
)

select
    subscription_id
    ,user_id
    ,subscription_token
    ,subscription_renew_period_type
    ,subscription_cancelled_reason
    ,datediff(day,subscription_created_at_utc,coalesce(subscription_cancelled_at_utc,sysdate())) as membership_tenure
    ,is_uncancelled_membership
    ,is_active_membership
    ,subscription_created_at_utc
    ,subscription_cancelled_at_utc
    ,updated_at_utc
from membership_joins