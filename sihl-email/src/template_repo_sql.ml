module type Sig = sig
  val lifecycles : Sihl.Container.lifecycle list
  val register_migration : unit -> unit
  val register_cleaner : unit -> unit

  val get
    :  ?ctx:(string * string) list
    -> string
    -> Sihl.Contract.Email_template.t option Lwt.t

  val get_by_label
    :  ?ctx:(string * string) list
    -> ?language:string
    -> string
    -> Sihl.Contract.Email_template.t option Lwt.t

  val insert
    :  ?ctx:(string * string) list
    -> Sihl.Contract.Email_template.t
    -> unit Lwt.t

  val update
    :  ?ctx:(string * string) list
    -> Sihl.Contract.Email_template.t
    -> unit Lwt.t
end

let template =
  let open Sihl.Contract.Email_template in
  let encode m =
    Ok
      ( m.id
      , (m.label, (m.language, (m.text, (m.html, (m.created_at, m.updated_at)))))
      )
  in
  let decode (id, (label, (language, (text, (html, (created_at, updated_at))))))
    =
    Ok { id; label; language; text; html; created_at; updated_at }
  in
  Caqti_type.(
    custom
      ~encode
      ~decode
      (t2
         string
         (t2
            string
            (t2
               (option string)
               (t2 string (t2 (option string) (t2 ptime ptime)))))))
;;

module MakeMariaDb (MigrationService : Sihl.Contract.Migration.Sig) : Sig =
struct
  let lifecycles = [ Sihl.Database.lifecycle; MigrationService.lifecycle ]

  module Sql = struct
    let get_request =
      let open Caqti_request.Infix in
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
          language,
          content_text,
          content_html,
          created_at,
          updated_at
        FROM email_templates
        WHERE email_templates.uuid = UNHEX(REPLACE(?, '-', ''))
      |sql}
      |> Caqti_type.(string ->? template)
    ;;

    let get ?ctx id = Sihl.Database.find_opt ?ctx get_request id

    let get_by_label_request ?(with_language = false) ctype =
      let open Caqti_request.Infix in
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
          language,
          content_text,
          content_html,
          created_at,
          updated_at
        FROM email_templates
        WHERE email_templates.label = ?
      |sql}
      |> (fun sql ->
      if with_language
      then
        {sql| AND email_templates.language = ? |sql}
        |> Format.asprintf "%s\n%s" sql
      else sql)
      |> ctype ->? template
    ;;

    let get_by_label ?ctx ?language label =
      match language with
      | None ->
        Sihl.Database.find_opt
          ?ctx
          (get_by_label_request Caqti_type.string)
          label
      | Some language ->
        Sihl.Database.find_opt
          ?ctx
          (get_by_label_request
             ~with_language:true
             Caqti_type.(t2 string string))
          (label, language)
    ;;

    let insert_request =
      let open Caqti_request.Infix in
      {sql|
        INSERT INTO email_templates (
          uuid,
          label,
          language,
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
          ?,
          ?
        )
      |sql}
      |> template ->. Caqti_type.unit
    ;;

    let insert ?ctx template = Sihl.Database.exec ?ctx insert_request template

    let update_request =
      let open Caqti_request.Infix in
      {sql|
        UPDATE email_templates
        SET
          label = $2,
          language = $3,
          content_text = $4,
          content_html = $5,
          created_at = $6,
          updated_at = $7
        WHERE email_templates.uuid = UNHEX(REPLACE($1, '-', ''))
      |sql}
      |> template ->. Caqti_type.unit
    ;;

    let update ?ctx template = Sihl.Database.exec ?ctx update_request template

    let clean_request =
      let open Caqti_request.Infix in
      "TRUNCATE TABLE email_templates" |> Caqti_type.(unit ->. unit)
    ;;

    let clean ?ctx () = Sihl.Database.exec ?ctx clean_request ()
  end

  module Migration = struct
    let fix_collation =
      Sihl.Database.Migration.create_step
        ~label:"fix collation"
        "SET collation_server = 'utf8mb4_unicode_ci'"
    ;;

    let create_templates_table =
      Sihl.Database.Migration.create_step
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
          ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        |sql}
    ;;

    let rename_name_column =
      Sihl.Database.Migration.create_step
        ~label:"rename name column"
        {sql|
          ALTER TABLE email_templates
            CHANGE COLUMN `name` label VARCHAR(128) NOT NULL
        |sql}
    ;;

    let add_updated_at_column =
      Sihl.Database.Migration.create_step
        ~label:"add updated_at column"
        {sql|
          ALTER TABLE email_templates
            ADD COLUMN updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
        |sql}
    ;;

    let make_html_nullable =
      Sihl.Database.Migration.create_step
        ~label:"make html nullable"
        {sql|
          ALTER TABLE email_templates
            MODIFY content_html TEXT NULL
        |sql}
    ;;

    let add_language_column =
      Sihl.Database.Migration.create_step
        ~label:"add language column"
        {sql|
          ALTER TABLE email_templates
            ADD COLUMN language VARCHAR(128) NULL
              AFTER `label`
        |sql}
    ;;

    let remove_unique_label_constraint =
      Sihl.Database.Migration.create_step
        ~label:"remove unique label constraint"
        {sql|
          ALTER TABLE email_templates
            DROP CONSTRAINT unique_name
        |sql}
    ;;

    let make_label_language_combination_unique =
      Sihl.Database.Migration.create_step
        ~label:"make label language combination unique"
        {sql|
          ALTER TABLE email_templates
            ADD CONSTRAINT unique_label_language UNIQUE(label, language)
        |sql}
    ;;

    let migration () =
      Sihl.Database.Migration.(
        empty "email"
        |> add_step fix_collation
        |> add_step create_templates_table
        |> add_step rename_name_column
        |> add_step add_updated_at_column
        |> add_step make_html_nullable
        |> add_step add_language_column
        |> add_step remove_unique_label_constraint
        |> add_step make_label_language_combination_unique)
    ;;
  end

  let register_migration () =
    MigrationService.register_migration (Migration.migration ())
  ;;

  let register_cleaner () = Sihl.Cleaner.register_cleaner Sql.clean
  let get = Sql.get
  let get_by_label = Sql.get_by_label
  let insert = Sql.insert
  let update = Sql.update
end

module MakePostgreSql (MigrationService : Sihl.Contract.Migration.Sig) : Sig =
struct
  let lifecycles = [ Sihl.Database.lifecycle; MigrationService.lifecycle ]

  module Sql = struct
    let get_request =
      let open Caqti_request.Infix in
      {sql|
        SELECT
          uuid,
          label,
          language,
          content_text,
          content_html,
          created_at,
          updated_at
        FROM email_templates
        WHERE email_templates.uuid = $1::uuid
      |sql}
      |> Caqti_type.string ->? template
    ;;

    let get ?ctx id = Sihl.Database.find_opt ?ctx get_request id

    let get_by_label_request ?(with_language = false) ctype =
      let open Caqti_request.Infix in
      {sql|
        SELECT
          uuid,
          label,
          language,
          content_text,
          content_html,
          created_at,
          updated_at
        FROM email_templates
        WHERE email_templates.label = ?
      |sql}
      |> (fun sql ->
      if with_language
      then
        {sql| AND email_templates.language = ? |sql}
        |> Format.asprintf "%s\n%s" sql
      else sql)
      |> ctype ->? template
    ;;

    let get_by_label ?ctx ?language label =
      match language with
      | None ->
        Sihl.Database.find_opt
          ?ctx
          (get_by_label_request Caqti_type.string)
          label
      | Some language ->
        Sihl.Database.find_opt
          ?ctx
          (get_by_label_request
             ~with_language:true
             Caqti_type.(t2 string string))
          (label, language)
    ;;

    let insert_request =
      let open Caqti_request.Infix in
      {sql|
        INSERT INTO email_templates (
          uuid,
          label,
          language,
          content_text,
          content_html,
          created_at,
          updated_at
        ) VALUES (
          $1::uuid,
          $2,
          $3,
          $4,
          $5,
          $6 AT TIME ZONE 'UTC',
          $7 AT TIME ZONE 'UTC'
        )
      |sql}
      |> template ->. Caqti_type.unit
    ;;

    let insert ?ctx template = Sihl.Database.exec ?ctx insert_request template

    let update_request =
      let open Caqti_request.Infix in
      {sql|
        UPDATE email_templates
        SET
          label = $2,
          language = $3,
          content_text = $4,
          content_html = $5,
          created_at = $6 AT TIME ZONE 'UTC',
          updated_at = $7 AT TIME ZONE 'UTC'
        WHERE email_templates.uuid = $1::uuid
      |sql}
      |> template ->. Caqti_type.unit
    ;;

    let update ?ctx template = Sihl.Database.exec ?ctx update_request template

    let clean_request =
      let open Caqti_request.Infix in
      "TRUNCATE TABLE email_templates CASCADE" |> Caqti_type.(unit ->. unit)
    ;;

    let clean ?ctx () = Sihl.Database.exec ?ctx clean_request ()
  end

  module Migration = struct
    let create_templates_table =
      Sihl.Database.Migration.create_step
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
          )
        |sql}
    ;;

    let rename_name_column =
      Sihl.Database.Migration.create_step
        ~label:"rename name column"
        {sql|
          ALTER TABLE email_templates
            RENAME COLUMN name TO label
        |sql}
    ;;

    let add_updated_at_column =
      Sihl.Database.Migration.create_step
        ~label:"add updated_at column"
        {sql|
          ALTER TABLE email_templates
            ADD COLUMN updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
        |sql}
    ;;

    let make_html_nullable =
      Sihl.Database.Migration.create_step
        ~label:"make html nullable"
        {sql|
          ALTER TABLE email_templates
            ALTER COLUMN content_html DROP NOT NULL
        |sql}
    ;;

    let remove_timezone =
      Sihl.Database.Migration.create_step
        ~label:"remove timezone info from timestamps"
        {sql|
          ALTER TABLE email_templates
            ALTER COLUMN created_at TYPE TIMESTAMP,
            ALTER COLUMN updated_at TYPE TIMESTAMP
        |sql}
    ;;

    let add_language_column =
      Sihl.Database.Migration.create_step
        ~label:"add language column"
        {sql|
          ALTER TABLE email_templates
            ADD COLUMN language VARCHAR(128) NULL
        |sql}
    ;;

    let remove_unique_label_constraint =
      Sihl.Database.Migration.create_step
        ~label:"remove unique label constraint"
        {sql|
          ALTER TABLE email_templates
            DROP CONSTRAINT email_templates_name_key
        |sql}
    ;;

    let make_label_language_combination_unique =
      Sihl.Database.Migration.create_step
        ~label:"make label language combination unique"
        {sql|
          ALTER TABLE email_templates
            ADD CONSTRAINT email_templates_label_language_key UNIQUE(label, language)
        |sql}
    ;;

    let migration () =
      Sihl.Database.Migration.(
        empty "email"
        |> add_step create_templates_table
        |> add_step rename_name_column
        |> add_step add_updated_at_column
        |> add_step make_html_nullable
        |> add_step remove_timezone
        |> add_step add_language_column
        |> add_step remove_unique_label_constraint
        |> add_step make_label_language_combination_unique)
    ;;
  end

  let register_migration () =
    MigrationService.register_migration (Migration.migration ())
  ;;

  let register_cleaner () = Sihl.Cleaner.register_cleaner Sql.clean
  let get = Sql.get
  let get_by_label = Sql.get_by_label
  let insert = Sql.insert
  let update = Sql.update
end
