with

tag as ( select * from {{ source('cc', 'tags') }} where not _fivetran_deleted)

select
    id as tag_id
    ,{{ clean_strings('key') }} as tag_name
    ,user_id
    ,purpose as tag_purpose
    ,created_at as created_at_utc
    ,updated_at as updated_at_utc

from tag
