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
