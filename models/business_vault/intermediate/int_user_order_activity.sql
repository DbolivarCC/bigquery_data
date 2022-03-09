with

user as ( select * from {{ ref('stg_cc__users') }} where dbt_valid_to is null )
,order_info as ( select * from {{ ref('orders') }} )


,user_order_activity as (
    select
        user_id
        ,count(order_id) as total_order_count
        ,count_if(is_completed_order and is_membership_order) as total_completed_membership_orders
        ,count_if(is_paid_order and not is_cancelled_order and is_ala_carte_order) as total_paid_ala_carte_order_count
        ,count_if(is_paid_order and not is_cancelled_order and is_membership_order) total_paid_membership_order_count
        ,count_if(is_paid_order and not is_cancelled_order and is_membership_order and sysdate()::date - order_paid_at_utc::date <= 90) as last_90_days_paid_membership_order_count
        ,sum(iff(is_paid_order and not is_cancelled_order,net_revenue,0)) as lifetime_net_revenue
        ,count_if(is_paid_order and not is_cancelled_order) as lifetime_paid_order_count
        ,max(iff(is_completed_order and not is_paid_order and not is_cancelled_order,completed_order_rank,0)) as last_completed_unpaid_order_rank
        ,count_if(is_gift_order and is_paid_order and not is_cancelled_order) as total_paid_gift_order_count
        ,sum(iff(is_paid_order and not is_cancelled_order and order_paid_at_utc >= dateadd('month',-6,sysdate()),net_revenue,0)) as six_month_net_revenue
        ,sum(iff(is_paid_order and not is_cancelled_order and order_paid_at_utc >= dateadd('month',-12,sysdate()),net_revenue,0)) as twelve_month_net_revenue
        ,count_if(is_paid_order and not is_cancelled_order and order_paid_at_utc >= dateadd('month',-12,sysdate())) as twelve_month_purchase_count
        ,count_if(is_paid_order and not is_cancelled_order and order_paid_at_utc >= dateadd('day',-90,sysdate())) as last_90_days_paid_order_count
        ,count_if(is_paid_order and not is_cancelled_order and order_paid_at_utc >= dateadd('day',-180,sysdate())) as last_180_days_paid_order_count
        ,count_if(has_been_delivered and delivered_at_utc >= dateadd('day',-7,sysdate())) as recent_delivered_order_count
        ,min(iff(is_paid_order,order_paid_at_utc::date,null)) as customer_cohort_date
        ,min(iff(is_paid_order and is_membership_order,order_paid_at_utc::date,null)) as membership_cohort_date
        ,max(iff(is_paid_order and is_membership_order,order_paid_at_utc::date,null)) as last_paid_membership_order_date
        ,max(iff(is_paid_order and is_ala_carte_order,order_paid_at_utc::date,null)) as last_paid_ala_carte_order_date
        ,max(iff(completed_order_rank = 1,order_checkout_completed_at_utc,null)) as first_completed_order_date
        ,max(iff(completed_order_rank = 1,visit_id,null)) as first_completed_order_visit_id
    from order_info
    group by 1
)

,user_percentiles as (
    select
        *
        ,ntile(100) over(partition by six_month_net_revenue > 0 order by six_month_net_revenue) as six_month_net_revenue_percentile
        ,ntile(100) over(partition by twelve_month_net_revenue > 0 order by twelve_month_net_revenue) as twelve_month_net_revenue_percentile
        ,ntile(100) over(partition by lifetime_net_revenue > 0 order by lifetime_net_revenue) as lifetime_net_revenue_percentile
    from user_order_activity
)

,order_frequency as (
    select
        user_id
        
        ,lead(case when paid_order_rank is not null then order_paid_at_utc::date end,1) 
            over (partition by user_id order by paid_order_rank)  - order_paid_at_utc::date as days_to_next_paid_order
        
        ,lead(case when paid_membership_order_rank is not null then order_paid_at_utc::date end,1) 
            over (partition by user_id order by paid_membership_order_rank)  - order_paid_at_utc::date as days_to_next_paid_membership_order
        
        ,lead(case when paid_ala_carte_order_rank is not null then order_paid_at_utc::date end,1) 
            over (partition by user_id order by paid_ala_carte_order_rank)  - order_paid_at_utc::date as days_to_next_paid_ala_carte_order
    from order_info
)

,average_order_days as (
    select
        user_id
        ,avg(days_to_next_paid_order) as average_order_frequency_days
        ,avg(days_to_next_paid_membership_order) as average_membership_order_frequency_days
        ,avg(days_to_next_paid_ala_carte_order) as average_ala_carte_order_frequency_days
    from order_frequency
    group by 1
)

,user_activity_joins as (
    select
        user.user_id
        ,user_percentiles.user_id as order_user_id
        ,zeroifnull(user_percentiles.total_completed_membership_orders) as total_completed_membership_orders
        ,zeroifnull(user_percentiles.total_paid_ala_carte_order_count) as total_paid_ala_carte_order_count
        ,zeroifnull(user_percentiles.total_paid_membership_order_count) as total_paid_membership_order_count
        ,zeroifnull(user_percentiles.last_90_days_paid_membership_order_count) as last_90_days_paid_membership_order_count
        ,zeroifnull(user_percentiles.lifetime_net_revenue) as lifetime_net_revenue
        ,zeroifnull(user_percentiles.lifetime_paid_order_count) as lifetime_paid_order_count
        ,zeroifnull(user_percentiles.last_completed_unpaid_order_rank) as last_completed_unpaid_order_rank
        ,zeroifnull(user_percentiles.total_paid_gift_order_count) as total_paid_gift_order_count
        ,zeroifnull(user_percentiles.six_month_net_revenue) as six_month_net_revenue
        ,zeroifnull(user_percentiles.twelve_month_net_revenue) as twelve_month_net_revenue
        ,zeroifnull(user_percentiles.twelve_month_purchase_count) as twelve_month_purchase_count
        ,zeroifnull(user_percentiles.last_90_days_paid_order_count) as last_90_days_paid_order_count
        ,zeroifnull(user_percentiles.last_180_days_paid_order_count) as last_180_days_paid_order_count
        ,zeroifnull(user_percentiles.recent_delivered_order_count) as recent_delivered_order_count
        ,zeroifnull(user_percentiles.six_month_net_revenue_percentile) as six_month_net_revenue_percentile
        ,zeroifnull(user_percentiles.twelve_month_net_revenue_percentile) as twelve_month_net_revenue_percentile
        ,zeroifnull(user_percentiles.lifetime_net_revenue_percentile) as lifetime_net_revenue_percentile
        ,average_order_days.average_order_frequency_days
        ,average_order_days.average_membership_order_frequency_days
        ,average_order_days.average_ala_carte_order_frequency_days
        ,user_percentiles.customer_cohort_date
        ,user_percentiles.membership_cohort_date
        ,user_percentiles.last_paid_membership_order_date
        ,user_percentiles.last_paid_ala_carte_order_date
        ,user_percentiles.first_completed_order_date
        ,user_percentiles.first_completed_order_visit_id
    from user
        left join user_percentiles on user.user_id = user_percentiles.user_id
        left join average_order_days on user.user_id = average_order_days.user_id
)

select * from user_activity_joins
