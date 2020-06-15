module Sql = struct
  module Model = Sihl.Email.Template

  let get connection =
    let module Connection = (val connection : Caqti_lwt.CONNECTION) in
    let request =
      Caqti_request.find Caqti_type.string Model.t
        {sql|
        SELECT
          uuid,
          label,
          content_text,
          content_html,
          status,
          created_at
        FROM email_templates
        WHERE email_templates.uuid = ?
        |sql}
    in
    Connection.find request

  (* TODO split into insert and update *)
  let upsert connection =
    let module Connection = (val connection : Caqti_lwt.CONNECTION) in
    let request =
      Caqti_request.exec Model.t
        {sql|
        INSERT INTO email_templates (
          uuid,
          label,
          content_text,
          content_html,
          status,
          created_at
        ) VALUES (
          ?,
          ?,
          ?,
          ?,
          ?,
          ?
        ) ON CONFLICT (id)
        DO UPDATE SET
          label = EXCLUDED.label,
          content_text = EXCLUDED.content_text,
          content_html = EXCLUDED.content_html,
          status = EXCLUDED.status
        |sql}
    in
    Connection.exec request

  let clean connection =
    let module Connection = (val connection : Caqti_lwt.CONNECTION) in
    let request =
      Caqti_request.exec Caqti_type.unit
        {sql|
        TRUNCATE TABLE email_templates CASCADE;
         |sql}
    in
    Connection.exec request
end

module Migration = struct
  let create_templates_table =
    Sihl.Migration.create_step ~label:"create templates table"
      {sql|
CREATE TABLE email_templates (
  id SERIAL,
  uuid UUID NOT NULL,
  label VARCHAR(255) NOT NULL,
  content_text TEXT NOT NULL,
  content_html TEXT NOT NULL,
  status VARCHAR(128) NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (id),
  UNIQUE (uuid)
);
|sql}

  let migration () =
    Sihl.Migration.(empty "email" |> add_step create_templates_table)
end

let migrate = Migration.migration

let get ~id connection = Sql.get connection id

(* TODO sihl_user has to seed templates properly
let clean connection = Sql.clean connection () *)
let clean _ = Lwt.return @@ Ok ()
