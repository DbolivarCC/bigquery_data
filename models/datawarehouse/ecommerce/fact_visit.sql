with

all_events as ( select * from {{ ref('int_visit_events__unioned') }} ),
visits as ( select * from {{ ref('stg_cc__event_visits') }} ),

base as (

    select
        *
    from all_events
    where event_name = 'visit_start'

),

small_events as (

    select 
        *
    from all_events
    where visit_id in (select visit_id from base)

),

aggregate_events as (

    select
        visit_id
        ,array_agg(event_name) within group (order by occurred_at_utc, event_id)::variant as visit_event_sequence
    from small_events
    group by 1

),

joined_visits as (

    select 
        visits.visit_id
        ,visits.user_id
        ,visits.visit_token
        ,visits.visitor_token
        ,visits.visit_browser
        ,visits.visit_city
        ,visits.visit_region
        ,visits.visit_ip
        ,visits.visit_os
        ,visits.visit_device_type
        ,visits.visit_user_agent
        ,visits.visit_referrer
        ,visits.visit_referring_domain
        ,visits.visit_search_keyword
        ,visits.visit_landing_page
        ,visits.visit_landing_page_path
        ,visits.is_homepage_landing
        ,visits.utm_content
        ,visits.utm_campaign
        ,visits.utm_term
        ,visits.utm_medium
        ,visits.utm_source
        ,visits.started_at_utc
        ,visits.updated_at_utc
        ,aggregate_events.visit_event_sequence
    from visits
        inner join aggregate_events on visits.visit_id = aggregate_events.visit_id

)

select * from joined_visits