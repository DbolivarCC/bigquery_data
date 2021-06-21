{{
  config(
    tags=["events"]
  )
}}

with base as (
  
  select * from {{ ref('base_cc__ahoy_events') }}

),

event_checkout_payment_selected as (

  select
     event_id
    ,visit_id
    ,occurred_at_utc
    ,user_id
  from 
    base
  where 
    event_name = 'custom_event'
      and event_json:category::text = 'checkout'
      and event_json:action::text = 'reached-step' 
      and event_json:label::text = '2'

)

select * from event_checkout_payment_selected
