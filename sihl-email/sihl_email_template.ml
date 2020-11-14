open Lwt.Syntax
module Sig = Sihl.Email.Sig

module Make (Repo : Sig.TEMPLATE_REPO) : Sig.TEMPLATE_SERVICE = struct
  let get ~id = Repo.get ~id
  let get_by_name ~name = Repo.get_by_name ~name

  let create ~name ~html ~text =
    let template = Sihl.Email.Template.make ~text ~html name in
    let* () = Repo.insert ~template in
    let id = Sihl.Email.Template.id template in
    let* created = Repo.get ~id in
    match created with
    | None ->
      Logs.err (fun m ->
          m "EMAIL: Could not create template %a" Sihl.Email.Template.pp template);
      raise (Sihl.Email.Exception "Could not create email template")
    | Some created -> Lwt.return created
  ;;

  let update ~template =
    let* () = Repo.update ~template in
    let id = Sihl.Email.Template.id template in
    let* created = Repo.get ~id in
    match created with
    | None ->
      Logs.err (fun m ->
          m "EMAIL: Could not update template %a" Sihl.Email.Template.pp template);
      raise (Sihl.Email.Exception "Could not create email template")
    | Some created -> Lwt.return created
  ;;

  let render email =
    let template_id = Sihl.Email.template_id email in
    let template_data = Sihl.Email.template_data email in
    let text_content = Sihl.Email.text_content email in
    let html_content = Sihl.Email.html_content email in
    let* text_content, html_content =
      match template_id with
      | Some template_id ->
        let* template = Repo.get ~id:template_id in
        let* template =
          match template with
          | None ->
            raise
              (Sihl.Email.Exception
                 (Printf.sprintf "Template with id %s not found" template_id))
          | Some template -> Lwt.return template
        in
        Sihl.Email.Template.render template_data template |> Lwt.return
      | None -> Lwt.return (text_content, html_content)
    in
    email
    |> Sihl.Email.set_text_content text_content
    |> Sihl.Email.set_html_content html_content
    |> Lwt.return
  ;;

  let start () = Lwt.return ()
  let stop () = Lwt.return ()
  let lifecycle = Sihl.Container.Lifecycle.create "template" ~start ~stop

  let register () =
    Repo.register_migration ();
    Repo.register_cleaner ();
    Sihl.Container.Service.create lifecycle
  ;;
end

module Repo = struct
  module MakeMariaDb (MigrationService : Sihl.Migration.Sig.SERVICE) : Sig.TEMPLATE_REPO =
  struct
    module Sql = struct
      module Model = Sihl.Email.Template

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
        Sihl.Database.Service.query (fun (module Connection : Caqti_lwt.CONNECTION) ->
            Connection.find_opt get_request id
            |> Lwt.map Sihl.Database.Service.raise_error)
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
        Sihl.Database.Service.query (fun (module Connection : Caqti_lwt.CONNECTION) ->
            Connection.find_opt get_by_name_request name
            |> Lwt.map Sihl.Database.Service.raise_error)
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
        Sihl.Database.Service.query (fun (module Connection : Caqti_lwt.CONNECTION) ->
            Connection.exec insert_request template
            |> Lwt.map Sihl.Database.Service.raise_error)
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
        Sihl.Database.Service.query (fun (module Connection : Caqti_lwt.CONNECTION) ->
            Connection.exec update_request template
            |> Lwt.map Sihl.Database.Service.raise_error)
      ;;

      let clean_request =
        Caqti_request.exec
          Caqti_type.unit
          {sql|
        TRUNCATE TABLE email_templates;
         |sql}
      ;;

      let clean () =
        Sihl.Database.Service.query (fun (module Connection : Caqti_lwt.CONNECTION) ->
            Connection.exec clean_request () |> Lwt.map Sihl.Database.Service.raise_error)
      ;;
    end

    module Migration = struct
      let fix_collation =
        Sihl.Migration.create_step
          ~label:"fix collation"
          "SET collation_server = 'utf8mb4_unicode_ci'"
      ;;

      let create_templates_table =
        Sihl.Migration.create_step
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
        Sihl.Migration.(
          empty "email" |> add_step fix_collation |> add_step create_templates_table)
      ;;
    end

    let register_migration () =
      MigrationService.register_migration (Migration.migration ())
    ;;

    let register_cleaner () = Sihl.Repository.Service.register_cleaner Sql.clean
    let get = Sql.get
    let get_by_name = Sql.get_by_name
    let insert = Sql.insert
    let update = Sql.update
  end

  module MakePostgreSql (MigrationService : Sihl.Migration.Sig.SERVICE) :
    Sig.TEMPLATE_REPO = struct
    module Sql = struct
      module Model = Sihl.Email.Template

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
        Sihl.Database.Service.query (fun (module Connection : Caqti_lwt.CONNECTION) ->
            Connection.find_opt get_request id
            |> Lwt.map Sihl.Database.Service.raise_error)
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
        Sihl.Database.Service.query (fun (module Connection : Caqti_lwt.CONNECTION) ->
            Connection.find_opt get_by_name_request name
            |> Lwt.map Sihl.Database.Service.raise_error)
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
        Sihl.Database.Service.query (fun (module Connection : Caqti_lwt.CONNECTION) ->
            Connection.exec insert_request template
            |> Lwt.map Sihl.Database.Service.raise_error)
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
        Sihl.Database.Service.query (fun (module Connection : Caqti_lwt.CONNECTION) ->
            Connection.exec update_request template
            |> Lwt.map Sihl.Database.Service.raise_error)
      ;;

      let clean_request =
        Caqti_request.exec Caqti_type.unit "TRUNCATE TABLE email_templates CASCADE;"
      ;;

      let clean () =
        Sihl.Database.Service.query (fun (module Connection : Caqti_lwt.CONNECTION) ->
            Connection.exec clean_request () |> Lwt.map Sihl.Database.Service.raise_error)
      ;;
    end

    module Migration = struct
      let create_templates_table =
        Sihl.Migration.create_step
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

      let migration () = Sihl.Migration.(empty "email" |> add_step create_templates_table)
    end

    let register_migration () =
      MigrationService.register_migration (Migration.migration ())
    ;;

    let register_cleaner () = Sihl.Repository.Service.register_cleaner Sql.clean
    let get = Sql.get
    let get_by_name = Sql.get_by_name
    let insert = Sql.insert
    let update = Sql.update
  end
end
