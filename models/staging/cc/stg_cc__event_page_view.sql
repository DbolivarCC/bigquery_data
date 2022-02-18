{{
  config(
    materialized = 'incremental',
    unique_key = 'event_id',
    tags=["events"],
    enabled = false
  )
}}
    
with base as (
  
  select * 
  from {{ ref('base_cc__ahoy_events') }} as ae
  where  event_name = 'page_view' 

    {% if is_incremental() %}
      and ae.occurred_at_utc >= coalesce((select max(occurred_at_utc) from {{ this }}), '1900-01-01')
    {% endif %}
    
),

event_page_view as (

  select
     event_id
    ,visit_id
    ,occurred_at_utc
    ,user_id
    ,event_json:experiments          as experiments
    ,event_json:member::boolean      as is_member
    ,event_json:current_fc::int      as current_fc
    ,event_json:postal_code::text    as user_postal_code
    ,{{ clean_strings('event_json:referrer_url::text') }}   as referrer_url
    ,{{ clean_strings('event_json:url::text') }}            as page_viewed_url
  from 
    base

)

select * from event_page_view
