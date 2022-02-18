{{
  config(
        snowflake_warehouse = 'TRANSFORMING_M',
        enabled = false
    )
}}

with

visits as ( select * from {{ ref('visits') }} )
,all_events as ( select * from {{ ref('int_visit_events') }} )

,find_user_id as (

    select 
        *
        ,last_value(user_id) over(partition by visit_id order by occurred_at_utc, event_id) as last_user_id
    from all_events
)

,aggregate_events as (
    select
        visit_id
        ,last_user_id as user_id
        ,array_agg(event_name) within group (order by occurred_at_utc, event_id)::variant as visit_event_sequence
    from find_user_id
    group by 1,2
)

,joined_visits as (

    select 
        visits.visit_id
        ,coalesce(visits.user_id,aggregate_events.user_id) as user_id
        ,visits.visit_token
        ,visits.visitor_token
        ,visits.visit_browser
        ,visits.visit_city
        ,visits.visit_region
        ,visits.visit_country
        ,visits.visit_ip
        ,visits.visitor_ip_session
        ,visits.ip_session_visit_number
        ,visits.visit_os
        ,visits.visit_device_type
        ,visits.visit_user_agent
        ,visits.visit_referrer
        ,visits.visit_referring_domain
        ,visits.visit_search_keyword
        ,visits.visit_landing_page
        ,visits.visit_landing_page_path
        ,visits.utm_content
        ,visits.utm_campaign
        ,visits.utm_adset
        ,visits.utm_term
        ,visits.utm_medium
        ,visits.utm_source
        ,visits.channel
        ,visits.sub_channel
        ,visits.visit_attributed_source
        ,visits.is_wall_displayed
        ,visits.is_paid_referrer
        ,visits.is_social_platform_referrer
        ,visits.is_bot
        ,visits.is_internal_traffic
        ,visits.is_invalid_visit
        ,visits.is_homepage_landing
        ,visits.has_previous_order
        ,visits.has_previous_completed_order
        ,visits.has_previous_subscription
        ,visits.had_account_created
        ,visits.did_subscribe
        ,visits.did_sign_up
        ,visits.did_complete_order
        ,visits.pdp_views_count
        ,visits.pcp_impressions_count
        ,visits.pcp_impression_clicks_count
        ,visits.pdp_product_add_to_cart_count
        ,visits.started_at_utc
        ,visits.updated_at_utc
        ,aggregate_events.visit_event_sequence
    from visits
        left join aggregate_events on visits.visit_id = aggregate_events.visit_id
)

select * from joined_visits
