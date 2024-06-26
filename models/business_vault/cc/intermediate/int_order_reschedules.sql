with

order_reschedule as ( select * from {{ ref('stg_cc__events') }} where event_name = 'ORDER_RESCHEDULED')

select
    order_id
    ,occurred_at_utc
    ,reason as reschedule_reason
    ,old_scheduled_fulfillment_date
    ,new_scheduled_fulfillment_date
    ,user_making_change_id = user_id and user_making_change_id is not null as is_customer_reschedule
    ,count(event_id) over(partition by order_id) as reschedule_count
from order_reschedule
qualify row_number() over(partition by order_id order by occurred_at_utc desc) = 1
