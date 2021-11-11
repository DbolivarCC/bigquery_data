{{
  config(
        snowflake_warehouse = 'TRANSFORMING_M'
    )
}}

with

visits as ( select * from {{ ref('visit_classification') }} )
,visit_flags as ( select * from {{ ref('visit_flags') }} )

,joined_visits as (

    select 
        visits.visit_id
        ,visits.user_id
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
        ,visit_flags.is_bot
        ,visit_flags.is_internal_traffic
        ,visit_flags.is_invalid_visit
        ,visit_flags.is_homepage_landing
        ,visit_flags.has_previous_order
        ,visit_flags.has_previous_completed_order
        ,visit_flags.has_previous_subscription
        ,visit_flags.had_account_created
        ,visit_flags.did_subscribe
        ,visit_flags.did_sign_up
        ,visit_flags.did_complete_order
        ,visit_flags.pdp_views_count
        ,visit_flags.pcp_impressions_count
        ,visit_flags.pcp_impression_clicks_count
        ,visit_flags.pdp_product_add_to_cart_count
        ,visits.started_at_utc
        ,visits.updated_at_utc
    from visits
        left join visit_flags on visits.visit_id = visit_flags.visit_id
    where not visit_flags.is_invalid_visit
        and visits.visit_landing_page <> ''
        

)

select * from joined_visits