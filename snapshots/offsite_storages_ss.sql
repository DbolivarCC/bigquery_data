{% snapshot offsite_storages_ss %}

{{
   config(
       target_schema='snapshots',
       unique_key='id',

       strategy='timestamp',
       updated_at='updated_at'
   )
}}

select * from {{ source('cc', 'offsite_storages') }}

{% endsnapshot %}