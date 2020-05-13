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

module Migration = struct
  let create_templates_table =
    [%rapper
      execute
        {sql|
CREATE TABLE emails_templates (
  id serial,
  uuid uuid NOT NULL,
  label VARCHAR(128) NOT NULL,
  value VARCHAR(1000) NOT NULL,
  status VARCHAR(128) NOT NULL,
  PRIMARY KEY (id),
  UNIQUE (uuid)
);
|sql}]

  let migration () =
    ("emails", [ ("create templates table", create_templates_table) ])
end

let migrate = Migration.migration

let get ~id connection = Sql.get connection ~id

(* TODO sihl_user has to seed templates properly
let clean connection = Sql.clean connection () *)
let clean _ = Lwt.return @@ Ok ()
