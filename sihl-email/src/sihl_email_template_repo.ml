module type Sig = sig
  val register_migration : unit -> unit
  val register_cleaner : unit -> unit
  val get : id:string -> Sihl_type.Email_template.t option Lwt.t
  val get_by_name : name:string -> Sihl_type.Email_template.t option Lwt.t
  val insert : template:Sihl_type.Email_template.t -> unit Lwt.t
  val update : template:Sihl_type.Email_template.t -> unit Lwt.t
end

module MakeMariaDb (MigrationService : Sihl_contract.Migration.Sig) : Sig = struct
  module Sql = struct
    module Model = Sihl_type.Email_template

    let get_request =
      Caqti_request.find_opt
        Caqti_type.string
        Model.t
        {sql|
        SELECT
          LOWER(CONCAT(
           SUBSTR(HEX(uuid), 1, 8), '-',
           SUBSTR(HEX(uuid), 9, 4), '-',
           SUBSTR(HEX(uuid), 13, 4), '-',
           SUBSTR(HEX(uuid), 17, 4), '-',
           SUBSTR(HEX(uuid), 21)
           )),
          name,
          content_text,
          content_html,
          created_at
        FROM email_templates
        WHERE email_templates.uuid = UNHEX(REPLACE(?, '-', ''))
        |sql}
    ;;

    let get ~id =
      Sihl_persistence.Database.query (fun (module Connection : Caqti_lwt.CONNECTION) ->
          Connection.find_opt get_request id
          |> Lwt.map Sihl_persistence.Database.raise_error)
    ;;

    let get_by_name_request =
      Caqti_request.find_opt
        Caqti_type.string
        Model.t
        {sql|
        SELECT
          LOWER(CONCAT(
           SUBSTR(HEX(uuid), 1, 8), '-',
           SUBSTR(HEX(uuid), 9, 4), '-',
           SUBSTR(HEX(uuid), 13, 4), '-',
           SUBSTR(HEX(uuid), 17, 4), '-',
           SUBSTR(HEX(uuid), 21)
           )),
          name,
          content_text,
          content_html,
          created_at
        FROM email_templates
        WHERE email_templates.name = ?
        |sql}
    ;;

    let get_by_name ~name =
      Sihl_persistence.Database.query (fun (module Connection : Caqti_lwt.CONNECTION) ->
          Connection.find_opt get_by_name_request name
          |> Lwt.map Sihl_persistence.Database.raise_error)
    ;;

    let insert_request =
      Caqti_request.exec
        Model.t
        {sql|
        INSERT INTO email_templates (
          uuid,
          name,
          content_text,
          content_html,
          created_at
        ) VALUES (
          UNHEX(REPLACE(?, '-', '')),
          ?,
          ?,
          ?,
          ?
        )
        |sql}
    ;;

    let insert ~template =
      Sihl_persistence.Database.query (fun (module Connection : Caqti_lwt.CONNECTION) ->
          Connection.exec insert_request template
          |> Lwt.map Sihl_persistence.Database.raise_error)
    ;;

    let update_request =
      Caqti_request.exec
        Model.t
        {sql|
        UPDATE email_templates
        SET
          name = $2,
          content_text = $3,
          content_html = $4,
          created_at = $5
        WHERE email_templates.uuid = UNHEX(REPLACE($1, '-', ''))
        |sql}
    ;;

    let update ~template =
      Sihl_persistence.Database.query (fun (module Connection : Caqti_lwt.CONNECTION) ->
          Connection.exec update_request template
          |> Lwt.map Sihl_persistence.Database.raise_error)
    ;;

    let clean_request =
      Caqti_request.exec
        Caqti_type.unit
        {sql|
        TRUNCATE TABLE email_templates;
         |sql}
    ;;

    let clean () =
      Sihl_persistence.Database.query (fun (module Connection : Caqti_lwt.CONNECTION) ->
          Connection.exec clean_request ()
          |> Lwt.map Sihl_persistence.Database.raise_error)
    ;;
  end

  module Migration = struct
    let fix_collation =
      Sihl_type.Migration.create_step
        ~label:"fix collation"
        "SET collation_server = 'utf8mb4_unicode_ci'"
    ;;

    let create_templates_table =
      Sihl_type.Migration.create_step
        ~label:"create templates table"
        {sql|
CREATE TABLE IF NOT EXISTS email_templates (
  id BIGINT UNSIGNED AUTO_INCREMENT,
  uuid BINARY(16) NOT NULL,
  name VARCHAR(128) NOT NULL,
  content_text TEXT NOT NULL,
  content_html TEXT NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  CONSTRAINT unique_uuid UNIQUE KEY (uuid),
  CONSTRAINT unique_name UNIQUE KEY (name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
|sql}
    ;;

    let migration () =
      Sihl_type.Migration.(
        empty "email" |> add_step fix_collation |> add_step create_templates_table)
    ;;
  end

  let register_migration () = MigrationService.register_migration (Migration.migration ())
  let register_cleaner () = Sihl_persistence.Repository.register_cleaner Sql.clean
  let get = Sql.get
  let get_by_name = Sql.get_by_name
  let insert = Sql.insert
  let update = Sql.update
end

module MakePostgreSql (MigrationService : Sihl_contract.Migration.Sig) : Sig = struct
  module Sql = struct
    module Model = Sihl_type.Email_template

    let get_request =
      Caqti_request.find_opt
        Caqti_type.string
        Model.t
        {sql|
        SELECT
          uuid,
          name,
          content_text,
          content_html,
          created_at
        FROM email_templates
        WHERE email_templates.uuid = ?
        |sql}
    ;;

    let get ~id =
      Sihl_persistence.Database.query (fun (module Connection : Caqti_lwt.CONNECTION) ->
          Connection.find_opt get_request id
          |> Lwt.map Sihl_persistence.Database.raise_error)
    ;;

    let get_by_name_request =
      Caqti_request.find_opt
        Caqti_type.string
        Model.t
        {sql|
        SELECT
          uuid,
          name,
          content_text,
          content_html,
          created_at
        FROM email_templates
        WHERE email_templates.name = ?
        |sql}
    ;;

    let get_by_name ~name =
      Sihl_persistence.Database.query (fun (module Connection : Caqti_lwt.CONNECTION) ->
          Connection.find_opt get_by_name_request name
          |> Lwt.map Sihl_persistence.Database.raise_error)
    ;;

    let insert_request =
      Caqti_request.exec
        Model.t
        {sql|
        INSERT INTO email_templates (
          uuid,
          name,
          content_text,
          content_html,
          created_at
        ) VALUES (
          ?,
          ?,
          ?,
          ?,
          ?
        )
        |sql}
    ;;

    let insert ~template =
      Sihl_persistence.Database.query (fun (module Connection : Caqti_lwt.CONNECTION) ->
          Connection.exec insert_request template
          |> Lwt.map Sihl_persistence.Database.raise_error)
    ;;

    let update_request =
      Caqti_request.exec
        Model.t
        {sql|
        UPDATE email_templates
        SET
          name = $2,
          content_text = $3,
          content_html = $4,
          created_at = $5
        WHERE email_templates.uuid = $1
        |sql}
    ;;

    let update ~template =
      Sihl_persistence.Database.query (fun (module Connection : Caqti_lwt.CONNECTION) ->
          Connection.exec update_request template
          |> Lwt.map Sihl_persistence.Database.raise_error)
    ;;

    let clean_request =
      Caqti_request.exec Caqti_type.unit "TRUNCATE TABLE email_templates CASCADE;"
    ;;

    let clean () =
      Sihl_persistence.Database.query (fun (module Connection : Caqti_lwt.CONNECTION) ->
          Connection.exec clean_request ()
          |> Lwt.map Sihl_persistence.Database.raise_error)
    ;;
  end

  module Migration = struct
    let create_templates_table =
      Sihl_type.Migration.create_step
        ~label:"create templates table"
        {sql|
CREATE TABLE IF NOT EXISTS email_templates (
  id SERIAL,
  uuid UUID NOT NULL,
  name VARCHAR(128) NOT NULL,
  content_text TEXT NOT NULL,
  content_html TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (id),
  UNIQUE (uuid),
  UNIQUE (name)
);
|sql}
    ;;

    let migration () =
      Sihl_type.Migration.(empty "email" |> add_step create_templates_table)
    ;;
  end

  let register_migration () = MigrationService.register_migration (Migration.migration ())
  let register_cleaner () = Sihl_persistence.Repository.register_cleaner Sql.clean
  let get = Sql.get
  let get_by_name = Sql.get_by_name
  let insert = Sql.insert
  let update = Sql.update
end
