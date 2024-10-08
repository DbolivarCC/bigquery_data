with

dates as (
    select
        date(calendar_date) as calendar_date
        ,date(calendar_date_week) as calendar_date_week
        ,date(calendar_date_month) as calendar_date_month
        ,fiscal_week_num
        ,fiscal_month
        ,fiscal_year
    from {{ ref('retail_calendar') }}
    where calendar_date <= current_date()
)

,membership as ( select * from {{ ref('memberships') }} )
,cancelled_membership as ( select * from {{ ref('memberships') }} where not is_uncancelled_membership )

,union_memberships as (
    select
        dates.calendar_date
        ,dates.calendar_date_week
        ,dates.calendar_date_month
        ,dates.fiscal_week_num
        ,dates.fiscal_month
        ,dates.fiscal_year
        ,'MEMBERSHIP CREATED' as membership_event
        ,membership.subscription_id
        ,membership.user_id
        ,membership.subscription_created_at_utc as membership_date
        ,cast(membership.subscription_created_at_utc as date) as membership_created
        ,cast(membership.subscription_cancelled_at_utc as date) as membership_cancelled
        ,1 as membership_change
    from dates
        inner join membership on dates.calendar_date = cast(membership.subscription_created_at_utc as date)
    
    union all
    
    select
        dates.calendar_date
        ,dates.calendar_date_week
        ,dates.calendar_date_month
        ,dates.fiscal_week_num
        ,dates.fiscal_month
        ,dates.fiscal_year
        ,'MEMBERSHIP CANCELLED' as membership_event
        ,cancelled_membership.subscription_id
        ,cancelled_membership.user_id
        ,cancelled_membership.subscription_cancelled_at_utc as membership_date
        ,cast(cancelled_membership.subscription_created_at_utc as date) as membership_created
        ,cast(cancelled_membership.subscription_cancelled_at_utc as date) as membership_cancelled
        ,- 1 as membership_change
    from dates
        inner join cancelled_membership on dates.calendar_date = cast(cancelled_membership.subscription_cancelled_at_utc as date)
    
)

,calculate_daily_memberships as (
    select 
        {{ dbt_utils.surrogate_key(['calendar_date','membership_event','subscription_id']) }} as membership_activity_id
        ,*
        ,sum(membership_change) over(order by calendar_date) as net_daily_uncancelled_memberships
        ,sum(membership_change) over(order by calendar_date_week) as net_weekly_uncancelled_memberships
        ,sum(membership_change) over(order by calendar_date_month) as net_monthly_uncancelled_memberships
    from union_memberships
)

select * from calculate_daily_memberships
