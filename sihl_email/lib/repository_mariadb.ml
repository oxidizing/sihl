module Sql = struct
  module Model = struct
    open Model.Template

    let t =
      let encode m = Ok (m.id, m.label, m.value, m.status) in
      let decode (id, label, value, status) = Ok { id; label; value; status } in
      Caqti_type.(custom ~encode ~decode (tup4 string string string string))
  end

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
          value,
          status
        FROM emails_templates
        WHERE emails_templates.uuid = UNHEX(REPLACE(?, '-', ''))
        |sql}
    in
    Connection.find request

  let upsert connection =
    let module Connection = (val connection : Caqti_lwt.CONNECTION) in
    let request =
      Caqti_request.exec Model.t
        {sql|
        INSERT INTO emails_templates (
          uuid,
          label,
          value,
          status
        ) VALUES (
          UNHEX(REPLACE(?, '-', '')),
          ?,
          ?,
          ?
        ) ON DUPLICATE KEY UPDATE
        DO UPDATE SET
          label = VALUES(label),
          value = VALUES(username),
          status = VALUES(password)
        |sql}
    in
    Connection.exec request

  let clean =
    [%rapper
      execute
        {sql|
        TRUNCATE TABLE emails_templates CASCADE;
        |sql}]
end

module Migration = struct
  let migrate str connection =
    let module Connection = (val connection : Caqti_lwt.CONNECTION) in
    let request = Caqti_request.exec Caqti_type.unit str in
    Connection.exec request

  let fix_collation =
    migrate {sql|
SET collation_connection = 'utf8mb4_unicode_ci';
|sql}

  let create_templates_table =
    migrate
      {sql|
CREATE TABLE emails_templates (
  id BIGINT UNSIGNED AUTO_INCREMENT,
  uuid BINARY(16) NOT NULL,
  label VARCHAR(128) NOT NULL,
  value VARCHAR(1000) NOT NULL,
  status VARCHAR(128) NOT NULL,
  PRIMARY KEY (id),
  CONSTRAINT unique_uuid UNIQUE KEY (uuid)
) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
|sql}

  let migration () =
    ( "emails",
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
