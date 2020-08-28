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

    let find ctx ~value =
      DbService.query ctx (fun (module Connection : Caqti_lwt.CONNECTION) ->
          Connection.find find_request value)

    let find_opt ctx ~value =
      DbService.query ctx (fun (module Connection : Caqti_lwt.CONNECTION) ->
          Connection.find_opt find_request value)

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

    let insert ctx ~token =
      DbService.query ctx (fun (module Connection : Caqti_lwt.CONNECTION) ->
          Connection.exec insert_request token)

    let clean_request =
      Caqti_request.exec Caqti_type.unit "TRUNCATE token_tokens;"

    let clean ctx =
      DbService.query ctx (fun (module Connection : Caqti_lwt.CONNECTION) ->
          Connection.exec clean_request ())
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

  let register_migration () = MigrationService.register (Migration.migration ())

  let register_cleaner () = RepoService.register_cleaner Sql.clean

  let find = Sql.find

  let find_opt = Sql.find_opt

  let insert = Sql.insert
end
