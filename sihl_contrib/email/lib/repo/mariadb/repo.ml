module Sql = struct
  module Model = Sihl_email.Model.Template

  let get connection =
    let module Connection = (val connection : Caqti_lwt.CONNECTION) in
    let request =
      Caqti_request.find Caqti_type.string Model.t
        {sql|
        SELECT
          LOWER(CONCAT(
           SUBSTR(HEX(uuid), 1, 8), '-',
           SUBSTR(HEX(uuid), 9, 4), '-',
           SUBSTR(HEX(uuid), 13, 4), '-',
           SUBSTR(HEX(uuid), 17, 4), '-',
           SUBSTR(HEX(uuid), 21)
           )),
          label,
          content_text,
          content_html,
          status,
          created_at
        FROM email_templates
        WHERE email_templates.uuid = UNHEX(REPLACE(?, '-', ''))
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
          UNHEX(REPLACE(?, '-', '')),
          ?,
          ?,
          ?,
          ?,
          ?
        ) ON DUPLICATE KEY UPDATE
        DO UPDATE SET
          label = VALUES(label),
          content = VALUES(content),
          status = VALUES(status)
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
  let fix_collation =
    Sihl.Repo.Migration.Mariadb.migrate
      {sql|
SET collation_connection = 'utf8mb4_unicode_ci';
|sql}

  let create_templates_table =
    Sihl.Repo.Migration.Mariadb.migrate
      {sql|
CREATE TABLE email_templates (
  id BIGINT UNSIGNED AUTO_INCREMENT,
  uuid BINARY(16) NOT NULL,
  label VARCHAR(255) NOT NULL,
  content_text TEXT NOT NULL,
  content_html TEXT NOT NULL,
  status VARCHAR(128) NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  CONSTRAINT unique_uuid UNIQUE KEY (uuid)
) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
|sql}

  let migration () =
    ( "email",
      [
        ("fix collation", fix_collation);
        ("create templates table", create_templates_table);
      ] )
end

let migrate = Migration.migration

let get ~id connection = Sql.get connection id

(* TODO sihl_user has to seed templates properly
let clean connection = Sql.clean connection () *)
let clean _ = Lwt.return @@ Ok ()
