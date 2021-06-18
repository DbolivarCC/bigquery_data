{{
  config(
    tags=["events"]
  )
}}

with base as (
  select
    *
  from
    {{ ref('base_cc__ahoy_events') }}
),
event_subscription_renew_period_updated as (
  select
     event_id
    ,visit_id
    ,occurred_at_utc
    ,user_id
    ,event_json:experiments             as experiments
    ,event_json:member::boolean         as is_member
    ,event_json:renewal_period::text    as renewal_period
    ,event_json:subscription_id::int    as subscription_id
    ,event_json:user_id::int            as user_id
    ,event_json:user_token::text        as user_token
  from 
    base
  where 
    event_name = 'subscription_renew_period_updated'
)

select * from event_subscription_renew_period_updated
