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

let get ~id connection = Sql.get connection id

let clean connection = Sql.clean connection ()
