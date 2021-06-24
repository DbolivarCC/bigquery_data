with source as (

    select * from {{ source('cc', 'promotions') }}

),

renamed as (

    select
        id as promotion_id
        ,{{ clean_strings('promotion_type') }} as promotion_type
        ,always_available as promotion_is_always_available
        ,must_be_assigned_to_user as promotion_must_be_assigned_to_user
        ,must_be_assigned_to_order as promotion_must_be_assigned_to_order
        ,created_at as created_at_utc
        ,updated_at as updated_at_utc

    from source

)

select * from renamed