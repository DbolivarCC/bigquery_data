with

orders as ( select * from {{ ref('stg_cc__orders') }} )
,order_revenue as ( select * from {{ ref('int_order_revenue') }} )
,order_cost as ( select * from {{ ref('int_order_cost') }} )
,flags as ( select * from {{ ref('int_order_flags') }} )
,ranks as ( select * from {{ ref('int_order_ranks') }} )
,units as ( select * from {{ ref('int_order_units_pct') }} )
,shipments as ( select * from {{ ref('stg_cc__shipments') }} )
,postal_code as ( select * from {{ ref('stg_cc__postal_codes') }} )

,order_shipment as (
    select
        order_id
        ,count(distinct shipment_id) as shipment_count
        ,sum(easypost_postage_rate_usd) as shipment_cost
        ,max(lost_at_utc) as lost_at_utc
        ,max(shipped_at_utc) as shipped_at_utc
        ,max(delivered_at_utc) as delivered_at_utc
    from shipments
    group by 1
)

,order_joins as (
    select
        orders.order_id
        ,orders.parent_order_id
        ,orders.order_token
        ,orders.user_id
        ,orders.subscription_id
        ,orders.fc_id
        ,orders.visit_id
        ,orders.stripe_charge_id
        ,{{ get_join_key('fcs','fc_key','fc_id','orders','fc_id','order_updated_at_utc') }} as fc_key
        ,orders.order_identifier
        ,orders.order_current_state

        ,case
            when orders.parent_order_id is not null then 'CORP GIFT'
            else orders.order_type
         end as order_type
        
        ,orders.stripe_failure_code
        ,orders.order_delivery_street_address_1
        ,orders.order_delivery_street_address_2
        ,orders.order_delivery_city
        ,orders.order_delivery_state
        ,orders.order_delivery_postal_code
        ,orders.billing_address_1
        ,orders.billing_address_2
        ,orders.billing_city
        ,coalesce(postal_code.state_code,orders.billing_state) as billing_state
        ,orders.billing_postal_code
        ,zeroifnull(order_revenue.gross_product_revenue) as gross_product_revenue
        ,zeroifnull(order_revenue.membership_discount) as membership_discount
        ,zeroifnull(order_revenue.merch_discount) as merch_discount
        ,zeroifnull(order_revenue.free_protein_promotion) as free_protein_promotion
        ,zeroifnull(order_revenue.net_product_revenue) as net_product_revenue
        ,orders.order_shipping_fee_usd as shipping_revenue
        ,zeroifnull(order_revenue.free_shipping_discount) as free_shipping_discount
        ,zeroifnull(order_revenue.gross_revenue) as gross_revenue
        ,zeroifnull(order_revenue.new_member_discount) as new_member_discount
        ,zeroifnull(order_revenue.refund_amount) as refund_amount
        ,zeroifnull(order_revenue.gift_redemption) as gift_redemption
        ,zeroifnull(order_revenue.other_discount) as other_discount
        ,zeroifnull(order_revenue.net_revenue) as net_revenue
        ,zeroifnull(order_cost.product_cost) as product_cost
        ,zeroifnull(order_shipment.shipment_cost) as shipment_cost
        ,orders.coolant_weight_in_pounds
        ,orders.order_additional_coolant_weight_in_pounds
        ,orders.order_bids_count
        ,zeroifnull(order_shipment.shipment_count) as shipment_count
        ,flags.has_free_shipping
        ,flags.is_ala_carte_order
        ,flags.is_membership_order
        ,flags.is_completed_order
        ,flags.is_paid_order
        ,flags.is_cancelled_order
        ,flags.is_abandonded_order
        ,flags.is_gift_order
        ,flags.is_bulk_gift_order
        ,flags.is_gift_card_order
        ,flags.has_shipped
        ,flags.has_been_delivered
        ,flags.has_been_lost
        ,flags.is_fulfillment_risk
        ,ranks.overall_order_rank
        ,ranks.completed_order_rank
        ,ranks.paid_order_rank
        ,ranks.cancelled_order_rank
        ,ranks.ala_carte_order_rank
        ,ranks.completed_ala_carte_order_rank
        ,ranks.paid_ala_carte_order_rank
        ,ranks.cancelled_ala_carte_order_rank
        ,ranks.membership_order_rank
        ,ranks.completed_membership_order_rank
        ,ranks.paid_membership_order_rank
        ,ranks.cancelled_membership_order_rank
        ,ranks.unique_membership_order_rank
        ,ranks.completed_unique_membership_order_rank
        ,ranks.paid_unique_membership_order_rank
        ,ranks.cancelled_unique_membership_order_rank
        ,ranks.gift_order_rank
        ,ranks.completed_gift_order_rank
        ,ranks.paid_gift_order_rank
        ,ranks.cancelled_gift_order_rank
        ,ranks.gift_card_order_rank
        ,ranks.completed_gift_card_order_rank
        ,ranks.paid_gift_card_order_rank
        ,ranks.cancelled_gift_card_order_rank
        ,units.beef_units
        ,units.bison_units
        ,units.chicken_units
        ,units.desserts_units
        ,units.duck_units
        ,units.game_meat_units
        ,units.japanese_wagyu_units
        ,units.lamb_units
        ,units.pet_food_units
        ,units.plant_based_proteins_units
        ,units.pork_units
        ,units.salts_seasonings_units
        ,units.seafood_units
        ,units.starters_sides_units
        ,units.turkey_units
        ,units.wagyu_units
        ,units.bundle_units
        ,units.total_units
        ,units.pct_beef
        ,units.pct_bison
        ,units.pct_chicken
        ,units.pct_desserts
        ,units.pct_duck
        ,units.pct_game_meat
        ,units.pct_japanese_wagyu
        ,units.pct_lamb
        ,units.pct_pet_food
        ,units.pct_plant_based_proteins
        ,units.pct_pork
        ,units.pct_salts_seasonings
        ,units.pct_seafood
        ,units.pct_starters_sides
        ,units.pct_turkey
        ,units.pct_wagyu
        ,units.pct_bundle
        ,orders.order_created_at_utc
        ,orders.order_updated_at_utc
        ,orders.order_checkout_completed_at_utc
        ,orders.order_cancelled_at_utc
        ,orders.order_paid_at_utc
        ,orders.order_first_stuck_at_utc
        ,orders.customer_viewed_at_utc
        ,orders.next_box_notified_at_utc
        ,orders.order_scheduled_fulfillment_date_utc
        ,orders.order_scheduled_arrival_date_utc
        ,order_shipment.shipped_at_utc
        ,order_shipment.delivered_at_utc
        ,order_shipment.lost_at_utc
        
    from orders
        left join order_revenue on orders.order_id = order_revenue.order_id
        left join order_cost on orders.order_id = order_cost.order_id
        left join flags on orders.order_id = flags.order_id
        left join ranks on orders.order_id = ranks.order_id
        left join units on orders.order_id = units.order_id
        left join order_shipment on orders.order_id = order_shipment.order_id
        left join postal_code on orders.billing_postal_code = postal_code.postal_code
    
    /**** Removing these order types because they are just shell orders that provide no data value ****/
    /**** Children orders contain all the necessary information for revenue, addresses, dates, etc for the order ****/
    where orders.order_type not in ('BULK ORDER','BULK GIFT')
)

select * from order_joins
