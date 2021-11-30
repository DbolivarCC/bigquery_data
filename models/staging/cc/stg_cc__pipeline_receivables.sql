with source as (

    select * from {{ ref('pipeline_receivables_ss') }} where not _fivetran_deleted

),

renamed as (

    select
        id as pipeline_receivables_id
        , dbt_scd_id as pipeline_receivables_key
        , sku_id
        , quantity
        , marked_destroyed_at as marked_destroyed_at_utc
        , cut_id
        , weight
        , created_at as created_at_utc
        , quantity_received
        , received_at as received_at_utc
        , pipeline_order_id
        , updated_at as updated_at_utc
        , dbt_valid_to
        , dbt_valid_from
        , case
            when dbt_valid_from = first_value(dbt_valid_from) over(partition by id order by dbt_valid_from) then '1970-01-01'
            else dbt_valid_from
        end as adjusted_dbt_valid_from
        , coalesce(dbt_valid_to,'2999-01-01') as adjusted_dbt_valid_to

    from source

)

select * from renamed

