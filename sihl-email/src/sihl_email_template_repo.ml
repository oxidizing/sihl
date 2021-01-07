module type Sig = sig
  val lifecycles : Sihl_core.Container.Lifecycle.t list
  val register_migration : unit -> unit
  val register_cleaner : unit -> unit
  val get : string -> Sihl_contract.Email_template.t option Lwt.t
  val get_by_label : string -> Sihl_contract.Email_template.t option Lwt.t
  val insert : Sihl_contract.Email_template.t -> unit Lwt.t
  val update : Sihl_contract.Email_template.t -> unit Lwt.t
end

let template =
  let open Sihl_contract.Email_template in
  let encode m =
    Ok (m.id, (m.label, (m.text, (m.html, (m.created_at, m.updated_at)))))
  in
  let decode (id, (label, (text, (html, (created_at, updated_at))))) =
    Ok { id; label; text; html; created_at; updated_at }
  in
  Caqti_type.(
    custom
      ~encode
      ~decode
      (tup2
         string
         (tup2 string (tup2 string (tup2 (option string) (tup2 ptime ptime))))))
;;

module MakeMariaDb (MigrationService : Sihl_contract.Migration.Sig) : Sig =
struct
  let lifecycles =
    [ Sihl_persistence.Database.lifecycle
    ; Sihl_core.Cleaner.lifecycle
    ; MigrationService.lifecycle
    ]
  ;;

  module Sql = struct
    module Model = Sihl_contract.Email_template

    let get_request =
      Caqti_request.find_opt
        Caqti_type.string
        template
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
          created_at,
          updated_at
        FROM email_templates
        WHERE email_templates.uuid = UNHEX(REPLACE(?, '-', ''))
        |sql}
    ;;

    let get id =
      Sihl_persistence.Database.query
        (fun (module Connection : Caqti_lwt.CONNECTION) ->
          Connection.find_opt get_request id
          |> Lwt.map Sihl_persistence.Database.raise_error)
    ;;

    let get_by_label_request =
      Caqti_request.find_opt
        Caqti_type.string
        template
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
          created_at,
          updated_at
        FROM email_templates
        WHERE email_templates.label = ?
        |sql}
    ;;

    let get_by_label label =
      Sihl_persistence.Database.query
        (fun (module Connection : Caqti_lwt.CONNECTION) ->
          Connection.find_opt get_by_label_request label
          |> Lwt.map Sihl_persistence.Database.raise_error)
    ;;

    let insert_request =
      Caqti_request.exec
        template
        {sql|
        INSERT INTO email_templates (
          uuid,
          label,
          content_text,
          content_html,
          created_at,
          updated_at
        ) VALUES (
          UNHEX(REPLACE(?, '-', '')),
          ?,
          ?,
          ?,
          ?,
          ?
        )
        |sql}
    ;;

    let insert template =
      Sihl_persistence.Database.query
        (fun (module Connection : Caqti_lwt.CONNECTION) ->
          Connection.exec insert_request template
          |> Lwt.map Sihl_persistence.Database.raise_error)
    ;;

    let update_request =
      Caqti_request.exec
        template
        {sql|
        UPDATE email_templates
        SET
          label = $2,
          content_text = $3,
          content_html = $4,
          created_at = $5,
          updated_at = $6
        WHERE email_templates.uuid = UNHEX(REPLACE($1, '-', ''))
        |sql}
    ;;

    let update template =
      Sihl_persistence.Database.query
        (fun (module Connection : Caqti_lwt.CONNECTION) ->
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
      Sihl_persistence.Database.query
        (fun (module Connection : Caqti_lwt.CONNECTION) ->
          Connection.exec clean_request ()
          |> Lwt.map Sihl_persistence.Database.raise_error)
    ;;
  end

  module Migration = struct
    let fix_collation =
      Sihl_facade.Migration.create_step
        ~label:"fix collation"
        "SET collation_server = 'utf8mb4_unicode_ci'"
    ;;

    let create_templates_table =
      Sihl_facade.Migration.create_step
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

    let rename_name_column =
      Sihl_facade.Migration.create_step
        ~label:"rename name column"
        {sql|
ALTER TABLE email_templates
CHANGE COLUMN `name` label VARCHAR(128) NOT NULL;
|sql}
    ;;

    let add_updated_at_column =
      Sihl_facade.Migration.create_step
        ~label:"add updated_at column"
        {sql|
ALTER TABLE email_templates
ADD COLUMN updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP;
|sql}
    ;;

    let make_html_nullable =
      Sihl_facade.Migration.create_step
        ~label:"make html nullable"
        {sql|
ALTER TABLE email_templates
MODIFY content_html TEXT NULL;
|sql}
    ;;

    let migration () =
      Sihl_facade.Migration.(
        empty "email"
        |> add_step fix_collation
        |> add_step create_templates_table
        |> add_step rename_name_column
        |> add_step add_updated_at_column
        |> add_step make_html_nullable)
    ;;
  end

  let register_migration () =
    MigrationService.register_migration (Migration.migration ())
  ;;

  let register_cleaner () = Sihl_core.Cleaner.register_cleaner Sql.clean
  let get = Sql.get
  let get_by_label = Sql.get_by_label
  let insert = Sql.insert
  let update = Sql.update
end

module MakePostgreSql (MigrationService : Sihl_contract.Migration.Sig) : Sig =
struct
  let lifecycles =
    [ Sihl_persistence.Database.lifecycle
    ; Sihl_core.Cleaner.lifecycle
    ; MigrationService.lifecycle
    ]
  ;;

  module Sql = struct
    module Model = Sihl_contract.Email_template

    let get_request =
      Caqti_request.find_opt
        Caqti_type.string
        template
        {sql|
        SELECT
          uuid,
          label,
          content_text,
          content_html,
          created_at,
          updated_at
        FROM email_templates
        WHERE email_templates.uuid = ?
        |sql}
    ;;

    let get id =
      Sihl_persistence.Database.query
        (fun (module Connection : Caqti_lwt.CONNECTION) ->
          Connection.find_opt get_request id
          |> Lwt.map Sihl_persistence.Database.raise_error)
    ;;

    let get_by_label_request =
      Caqti_request.find_opt
        Caqti_type.string
        template
        {sql|
        SELECT
          uuid,
          label,
          content_text,
          content_html,
          created_at,
          updated_at
        FROM email_templates
        WHERE email_templates.label = ?
        |sql}
    ;;

    let get_by_label label =
      Sihl_persistence.Database.query
        (fun (module Connection : Caqti_lwt.CONNECTION) ->
          Connection.find_opt get_by_label_request label
          |> Lwt.map Sihl_persistence.Database.raise_error)
    ;;

    let insert_request =
      Caqti_request.exec
        template
        {sql|
        INSERT INTO email_templates (
          uuid,
          label,
          content_text,
          content_html,
          created_at,
          updated_at
        ) VALUES (
          ?,
          ?,
          ?,
          ?,
          ?,
          ?
        )
        |sql}
    ;;

    let insert template =
      Sihl_persistence.Database.query
        (fun (module Connection : Caqti_lwt.CONNECTION) ->
          Connection.exec insert_request template
          |> Lwt.map Sihl_persistence.Database.raise_error)
    ;;

    let update_request =
      Caqti_request.exec
        template
        {sql|
        UPDATE email_templates
        SET
          label = $2,
          content_text = $3,
          content_html = $4,
          created_at = $5,
          updated_at = $6
        WHERE email_templates.uuid = $1
        |sql}
    ;;

    let update template =
      Sihl_persistence.Database.query
        (fun (module Connection : Caqti_lwt.CONNECTION) ->
          Connection.exec update_request template
          |> Lwt.map Sihl_persistence.Database.raise_error)
    ;;

    let clean_request =
      Caqti_request.exec
        Caqti_type.unit
        "TRUNCATE TABLE email_templates CASCADE;"
    ;;

    let clean () =
      Sihl_persistence.Database.query
        (fun (module Connection : Caqti_lwt.CONNECTION) ->
          Connection.exec clean_request ()
          |> Lwt.map Sihl_persistence.Database.raise_error)
    ;;
  end

  module Migration = struct
    let create_templates_table =
      Sihl_facade.Migration.create_step
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

    let rename_name_column =
      Sihl_facade.Migration.create_step
        ~label:"rename name column"
        {sql|
ALTER TABLE email_templates
RENAME COLUMN name TO label;
|sql}
    ;;

    let add_updated_at_column =
      Sihl_facade.Migration.create_step
        ~label:"add updated_at column"
        {sql|
ALTER TABLE email_templates
ADD COLUMN updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW();
|sql}
    ;;

    let make_html_nullable =
      Sihl_facade.Migration.create_step
        ~label:"make html nullable"
        {sql|
ALTER TABLE email_templates
ALTER COLUMN content_html DROP NOT NULL;
|sql}
    ;;

    let migration () =
      Sihl_facade.Migration.(
        empty "email"
        |> add_step create_templates_table
        |> add_step rename_name_column
        |> add_step add_updated_at_column
        |> add_step make_html_nullable)
    ;;
  end

  let register_migration () =
    MigrationService.register_migration (Migration.migration ())
  ;;

  let register_cleaner () = Sihl_core.Cleaner.register_cleaner Sql.clean
  let get = Sql.get
  let get_by_label = Sql.get_by_label
  let insert = Sql.insert
  let update = Sql.update
end
