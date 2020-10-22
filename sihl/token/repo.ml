module MariaDb (MigrationService : Migration.Sig.SERVICE) : Sig.REPOSITORY = struct
  module Sql = struct
    let find_request =
      Caqti_request.find
        Caqti_type.string
        Model.t
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
    ;;

    let find_opt ctx ~value =
      Database.Service.query ctx (fun (module Connection : Caqti_lwt.CONNECTION) ->
          Connection.find_opt find_request value)
    ;;

    let find_by_id_request =
      Caqti_request.find
        Database.Id.t_string
        Model.t
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
        WHERE token_tokens.uuid = ?
        |sql}
    ;;

    let find_by_id_opt ctx ~id =
      Database.Service.query ctx (fun (module Connection : Caqti_lwt.CONNECTION) ->
          Connection.find_opt find_by_id_request id)
    ;;

    let insert_request =
      Caqti_request.exec
        Model.t
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
    ;;

    let insert ctx ~token =
      Database.Service.query ctx (fun (module Connection : Caqti_lwt.CONNECTION) ->
          Connection.exec insert_request token)
    ;;

    let update_request =
      Caqti_request.exec
        Model.t
        {sql|
        UPDATE token_tokens
        SET
          token_data = $3,
          token_kind = $4,
          status = $5,
          expires_at = $6,
          created_at = $7
        WHERE token_tokens.token_value = $2
        |sql}
    ;;

    let update ctx ~token =
      Database.Service.query ctx (fun (module Connection : Caqti_lwt.CONNECTION) ->
          Connection.exec update_request token)
    ;;

    let clean_request = Caqti_request.exec Caqti_type.unit "TRUNCATE token_tokens;"

    let clean ctx =
      Database.Service.query ctx (fun (module Connection : Caqti_lwt.CONNECTION) ->
          Connection.exec clean_request ())
    ;;
  end

  module Migration = struct
    let fix_collation =
      Migration.create_step
        ~label:"fix collation"
        "SET collation_server = 'utf8mb4_unicode_ci'"
    ;;

    let create_tokens_table =
      Migration.create_step
        ~label:"create tokens table"
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
    ;;

    let migration () =
      Migration.(empty "tokens" |> add_step fix_collation |> add_step create_tokens_table)
    ;;
  end

  let register_migration () = MigrationService.register (Migration.migration ())
  let register_cleaner () = Repository.Service.register_cleaner Sql.clean
  let find_opt = Sql.find_opt
  let find_by_id_opt = Sql.find_by_id_opt
  let insert = Sql.insert
  let update = Sql.update
end
