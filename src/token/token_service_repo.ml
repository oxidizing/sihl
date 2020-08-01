module MakeMariaDb
    (DbService : Data_db_sig.SERVICE)
    (RepoService : Data.Repo.Sig.SERVICE)
    (MigrationService : Data.Migration.Sig.SERVICE) : Token_sig.REPOSITORY =
struct
  module Sql = struct
    module Model = Token_core

    let find_request =
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

    let find connection ~value =
      let module Connection = (val connection : Caqti_lwt.CONNECTION) in
      Connection.find find_request value |> Lwt_result.map_err Caqti_error.show

    let find_opt connection ~value =
      let module Connection = (val connection : Caqti_lwt.CONNECTION) in
      Connection.find_opt find_request value
      |> Lwt_result.map_err Caqti_error.show

    let insert_request =
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

    let insert connection ~token =
      let module Connection = (val connection : Caqti_lwt.CONNECTION) in
      Connection.exec insert_request token
      |> Lwt_result.map_err Caqti_error.show

    let clean_request =
      Caqti_request.exec Caqti_type.unit "TRUNCATE token_tokens;"

    let clean connection =
      let module Connection = (val connection : Caqti_lwt.CONNECTION) in
      Connection.exec clean_request () |> Lwt_result.map_err Caqti_error.show
  end

  module Migration = struct
    let fix_collation =
      Data.Migration.create_step ~label:"fix collation"
        "SET collation_server = 'utf8mb4_unicode_ci'"

    let create_tokens_table =
      Data.Migration.create_step ~label:"create tokens table"
        {sql|
CREATE TABLE IF NOT EXISTS token_tokens (
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

  let register_migration ctx =
    MigrationService.register ctx (Migration.migration ())

  let register_cleaner ctx =
    let cleaner ctx = Sql.clean |> DbService.query ctx in
    RepoService.register_cleaner ctx cleaner

  let find ctx ~value = Sql.find ~value |> DbService.query ctx

  let find_opt ctx ~value = Sql.find_opt ~value |> DbService.query ctx

  let insert ctx ~token = Sql.insert ~token |> DbService.query ctx
end
