{{
  config(
    tags=["events"],
    enabled=false
  )
}}

with base as (
  
  select * from {{ ref('base_cc__ahoy_events') }}

),

event_update_subscription as (

  select
     event_id
    ,visit_id
    ,occurred_at_utc
    ,user_id
    ,event_json:experiments             as experiments
    ,event_json:member::boolean         as is_member
    ,event_json:renewal_period::text    as renewal_period
    ,event_json:subscription_id::int    as subscription_id
    ,event_json:user_token::text        as user_token
  from 
    base
  where 
    event_name = 'update_subscription'

)

select * from event_update_subscription