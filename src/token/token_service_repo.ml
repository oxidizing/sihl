module MariaDb = struct
  module Sql = struct
    module Model = Token_core

    let find connection ~value =
      let module Connection = (val connection : Caqti_lwt.CONNECTION) in
      let request =
        Caqti_request.find Caqti_type.string Model.t
          {sql|
        SELECT
          uuid,
          token_value,
          token_data,
          token_kind,
          status,
          expires_at,
          created_at
        FROM token_tokens
        WHERE token_tokens.token_value = ?
        |sql}
      in
      Connection.find request value |> Lwt_result.map_err Caqti_error.show

    let find_opt connection ~value =
      let module Connection = (val connection : Caqti_lwt.CONNECTION) in
      let request =
        Caqti_request.find Caqti_type.string Model.t
          {sql|
        SELECT
          uuid,
          token_value,
          token_data,
          token_kind,
          status,
          expires_at,
          created_at
        FROM token_tokens
        WHERE token_tokens.token_value = ?
        |sql}
      in
      Connection.find_opt request value |> Lwt_result.map_err Caqti_error.show

    let insert connection ~token =
      let module Connection = (val connection : Caqti_lwt.CONNECTION) in
      Logs.err (fun m -> m "Inserting token %a" Token_core.pp token);
      let request =
        Caqti_request.exec Model.t
          {sql|
        INSERT INTO token_tokens (
          uuid,
          token_value,
          token_data,
          token_kind,
          status,
          expires_at,
          created_at
        ) VALUES (
          $1,
          $2,
          $3,
          $4,
          $5,
          $6,
          $7
        )
|sql}
      in
      Connection.exec request token |> Lwt_result.map_err Caqti_error.show

    let clean connection =
      let module Connection = (val connection : Caqti_lwt.CONNECTION) in
      let request =
        Caqti_request.exec Caqti_type.unit
          {sql|
        TRUNCATE token_tokens;
           |sql}
      in
      Connection.exec request () |> Lwt_result.map_err Caqti_error.show
  end

  module Migration = struct
    let fix_collation =
      Data.Migration.create_step ~label:"fix collation"
        "SET collation_server = 'utf8mb4_unicode_ci'"

    let create_tokens_table =
      Data.Migration.create_step ~label:"create tokens table"
        {sql|
CREATE TABLE token_tokens (
  id BIGINT UNSIGNED AUTO_INCREMENT,
  uuid BINARY(16) NOT NULL,
  token_value VARCHAR(128) NOT NULL,
  token_data VARCHAR(1024),
  token_kind VARCHAR(128) NOT NULL,
  status VARCHAR(128) NOT NULL,
  expires_at TIMESTAMP NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  CONSTRAINT unqiue_uuid UNIQUE KEY (uuid),
  CONSTRAINT unique_value UNIQUE KEY (token_value)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
|sql}

    let migration () =
      Data.Migration.(
        empty "tokens" |> add_step fix_collation |> add_step create_tokens_table)
  end

  let find ~value connection = Sql.find connection ~value

  let find_opt ~value connection = Sql.find_opt connection ~value

  let insert ~token connection = Sql.insert connection ~token

  let migrate = Migration.migration

  let clean connection =
    let module Connection = (val connection : Caqti_lwt.CONNECTION) in
    let request = Caqti_request.exec Caqti_type.unit "TRUNCATE token_tokens;" in
    Connection.exec request () |> Lwt_result.map_err Caqti_error.show
end
