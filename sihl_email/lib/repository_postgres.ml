module Sql = struct
  open Model.Template

  let get =
    [%rapper
      get_one
        {sql|
        SELECT
          uuid as @string{id},
          @string{label},
          @string{value},
          @string{status}
        FROM emails_templates
        WHERE emails_templates.uuid = %string{id}
        |sql}
        record_out]

  let upsert =
    [%rapper
      execute
        {sql|
        INSERT INTO emails_templates (
          uuid,
          label,
          value,
          status
        ) VALUES (
          %string{id},
          %string{label},
          %string{value},
          %string{status}
        ) ON CONFLICT (id)
        DO UPDATE SET
          label = %string{label},
          value = %string{value},
          status = %string{status}
        |sql}
        record_in]

  let clean =
    [%rapper
      execute
        {sql|
        TRUNCATE TABLE emails_templates CASCADE;
        |sql}]
end

let get ~id connection = Sql.get connection ~id

let clean connection = Sql.clean connection ()
