with

/*** Only starting with dates after 2021-10-28 since that is when we started fully snapshotting the `sku_boxes` data in the new model ***/
dates as ( select calendar_date from {{ ref('stg_reference__date_spine') }} where calendar_date >= '2021-10-28' and calendar_date < sysdate()::date )
,sku_box as ( select * from {{ ref('stg_cc__sku_boxes') }} )
,fc_location as ( select * from {{ ref('stg_cc__fc_locations') }} )
,fc as ( select * from {{ ref('fcs') }} )
,sku as ( select * from {{ ref('skus') }} )
,lot as ( select * from {{ ref('lots') }} )
,sku_vendor as ( select * from {{ ref('stg_cc__sku_vendors') }} )

,inventory_snapshot as (
    select
        sku_box_id
        ,sku_box_key
        ,fc_id
        ,sku_id
        ,owner_id
        ,lot_id
        ,pallet_id
        ,sku_box_name
        ,min_weight
        ,max_weight
        ,quantity
        ,quantity_reserved
        ,quantity - quantity_reserved as quantity_available
        ,quantity_quarantined
        ,fc_location_parent_id as fc_location_id
        ,created_at_utc
        ,updated_at_utc
        ,marked_not_for_sale_at_utc
        ,marked_destroyed_at_utc
        ,delivered_at_utc
        ,moved_to_picking_at_utc
        ,dbt_valid_from::date as dbt_valid_from
        ,coalesce(dbt_valid_to,sysdate())::date as dbt_valid_to
        ,row_number() over(partition by sku_box_id, dbt_valid_from::date order by dbt_valid_from desc) as rn
    from sku_box
    qualify rn = 1
    order by dbt_valid_from
)

,daily_sku_boxes as (
    select
        dates.calendar_date as snapshot_date
        ,inventory_snapshot.sku_box_id
        ,inventory_snapshot.sku_box_key
        ,inventory_snapshot.fc_id
        ,inventory_snapshot.sku_id
        ,inventory_snapshot.owner_id
        ,inventory_snapshot.lot_id
        ,inventory_snapshot.pallet_id
        ,inventory_snapshot.sku_box_name
        ,inventory_snapshot.min_weight
        ,inventory_snapshot.max_weight
        ,inventory_snapshot.quantity
        ,inventory_snapshot.quantity_reserved
        ,inventory_snapshot.quantity - quantity_reserved as quantity_available
        ,inventory_snapshot.quantity_quarantined
        ,inventory_snapshot.fc_location_id
        ,inventory_snapshot.marked_destroyed_at_utc is not null as is_destroyed
        ,inventory_snapshot.created_at_utc
        ,inventory_snapshot.updated_at_utc
        ,inventory_snapshot.marked_not_for_sale_at_utc
        ,inventory_snapshot.marked_destroyed_at_utc
        ,inventory_snapshot.delivered_at_utc
        ,inventory_snapshot.moved_to_picking_at_utc
    from dates
        left join inventory_snapshot on dates.calendar_date >= inventory_snapshot.dbt_valid_from
            and dates.calendar_date < inventory_snapshot.dbt_valid_to
)

,sku_box_locations as (
    select 
        daily_sku_boxes.*
        ,fc_location.location_type
        ,fc_location.location_name
        
        ,case 
            when fc_location.is_sellable then daily_sku_boxes.quantity_available  
            else 0 
         end as quantity_sellable
        
        ,fc_location.is_sellable
    from daily_sku_boxes
        left join fc_location on daily_sku_boxes.fc_location_id = fc_location.fc_location_id
)

,inventory_joins as (
    select 
        {{ dbt_utils.surrogate_key(['snapshot_date','sku_box_key'] ) }} as inventory_snapshot_id
        ,sku_box_locations.*
        ,fc.fc_key
        ,sku.sku_key
        ,lot.lot_number
        ,sku_vendor.sku_vendor_name as sku_box_owner_name
        ,sku.sku_price_usd
        ,sku.sku_cost_usd
        ,sku.marketplace_cost_usd
        ,sku.is_marketplace
    from sku_box_locations
        left join sku_vendor on sku_box_locations.owner_id = sku_vendor.sku_vendor_id
        left join lot on sku_box_locations.lot_id = lot.lot_id

        /*** Get various join keys to be able to grab information at the time of snapshot date ****/
        left join fc on sku_box_locations.fc_id = fc.fc_id
            and snapshot_date >= fc.adjusted_dbt_valid_from
            and snapshot_date < fc.adjusted_dbt_valid_to
        left join sku on sku_box_locations.sku_id = sku.sku_id
            and snapshot_date >= sku.adjusted_dbt_valid_from
            and snapshot_date < sku.adjusted_dbt_valid_to
        
)

,add_sku_metrics as (
    select
        inventory_snapshot_id
        ,snapshot_date
        ,sku_box_id
        ,sku_box_key
        ,fc_id
        ,fc_key
        ,sku_id
        ,sku_key
        ,owner_id
        ,lot_number
        ,pallet_id
        ,fc_location_id
        ,sku_box_name
        ,sku_box_owner_name
        ,location_type
        ,location_name
        ,min_weight
        ,max_weight
        ,quantity
        ,quantity * sku_price_usd as potential_revenue
        ,iff(is_marketplace,quantity * marketplace_cost_usd,quantity * sku_cost_usd) as sku_cost
        ,quantity_reserved
        ,quantity_reserved * sku_price_usd as potential_revenue_reserved
        ,iff(is_marketplace,quantity_reserved * marketplace_cost_usd,quantity_reserved * sku_cost_usd) as sku_cost_reserved
        ,quantity_available
        ,quantity_available * sku_price_usd as potential_revenue_available
        ,iff(is_marketplace,quantity_available * marketplace_cost_usd, quantity_available * sku_cost_usd) as sku_cost_available
        ,quantity_quarantined
        ,quantity_quarantined * sku_price_usd as potential_revenue_quarantined
        ,iff(is_marketplace,quantity_quarantined * marketplace_cost_usd, quantity_quarantined * sku_cost_usd) as sku_cost_quarantined
        ,quantity_sellable
        ,quantity_sellable * sku_price_usd as potential_revenue_sellable
        ,iff(is_marketplace,quantity_sellable * marketplace_cost_usd, quantity_sellable * sku_cost_usd) as sku_cost_sellable
        ,is_sellable
        ,is_destroyed
        ,is_marketplace
        ,created_at_utc
        ,updated_at_utc
        ,marked_not_for_sale_at_utc
        ,marked_destroyed_at_utc
        ,delivered_at_utc
        ,moved_to_picking_at_utc
    from inventory_joins
)

select * from add_sku_metrics
