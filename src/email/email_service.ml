open Base
open Lwt.Syntax

module EnvConfigProvider (Config : Config_sig.SERVICE) :
  Email_sig.ConfigProvider.SMTP = struct
  let sender _ = Lwt.return @@ Config.read_string "SMTP_SENDER"

  let host _ = Lwt.return @@ Config.read_string "SMTP_HOST"

  let username _ = Lwt.return @@ Config.read_string "SMTP_USERNAME"

  let password _ = Lwt.return @@ Config.read_string "SMTP_PASSWORD"

  let port _ = Config.read_int_opt "SMTP_PORT" |> Lwt.return

  let start_tls _ = Lwt.return @@ Config.read_bool "SMTP_START_TLS"

  let ca_path _ = Config.read_string_opt "SMTP_CA_PATH" |> Lwt.return

  let ca_cert _ = Config.read_string_opt "SMTP_CA_CERT" |> Lwt.return
end

module Template = struct
  module Make (Log : Log.Sig.SERVICE) (Repo : Email_sig.Template.REPO) :
    Email_sig.Template.SERVICE = struct
    let lifecycle =
      Core.Container.Lifecycle.make "template" ~dependencies:[ Log.lifecycle ]
        (fun ctx ->
          Repo.register_migration ();
          Repo.register_cleaner ();
          Lwt.return ctx)
        (fun _ -> Lwt.return ())

    let get ctx ~id = Repo.get ctx ~id

    let get_by_name ctx ~name = Repo.get_by_name ctx ~name

    let create ctx ~name ~html ~text =
      let template = Email_core.Template.make ~text ~html name in
      let* () = Repo.insert ctx ~template in
      let id = Email_core.Template.id template in
      let* created = Repo.get ctx ~id in
      match created with
      | None ->
          Log.err (fun m ->
              m "EMAIL: Could not create template %a" Email_core.Template.pp
                template);
          raise (Email_core.Exception "Could not create email template")
      | Some created -> Lwt.return created

    let update ctx ~template =
      let* () = Repo.update ctx ~template in
      let id = Email_core.Template.id template in
      let* created = Repo.get ctx ~id in
      match created with
      | None ->
          Log.err (fun m ->
              m "EMAIL: Could not update template %a" Email_core.Template.pp
                template);
          raise (Email_core.Exception "Could not create email template")
      | Some created -> Lwt.return created

    let render ctx email =
      let template_id = Email_core.template_id email in
      let template_data = Email_core.template_data email in
      let text_content = Email_core.text_content email in
      let html_content = Email_core.html_content email in
      let* text_content, html_content =
        match template_id with
        | Some template_id ->
            let* template = Repo.get ctx ~id:template_id in
            let* template =
              match template with
              | None ->
                  raise
                    (Email_core.Exception
                       (Printf.sprintf "Template with id %s not found"
                          template_id))
              | Some template -> Lwt.return template
            in
            Email_core.Template.render template_data template |> Lwt.return
        | None -> Lwt.return (text_content, html_content)
      in
      email
      |> Email_core.set_text_content text_content
      |> Email_core.set_html_content html_content
      |> Lwt.return
  end

  module Repo = struct
    module MakeMariaDb
        (DbService : Data.Db.Sig.SERVICE)
        (RepoService : Data.Repo.Sig.SERVICE)
        (MigrationService : Data.Migration.Sig.SERVICE) :
      Email_sig.Template.REPO = struct
      module Sql = struct
        module Model = Email_core.Template

        let get_request =
          Caqti_request.find_opt Caqti_type.string Model.t
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

        let get ctx ~id =
          DbService.query ctx (fun (module Connection : Caqti_lwt.CONNECTION) ->
              Connection.find_opt get_request id)

        let get_by_name_request =
          Caqti_request.find_opt Caqti_type.string Model.t
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

        let get_by_name ctx ~name =
          DbService.query ctx (fun (module Connection : Caqti_lwt.CONNECTION) ->
              Connection.find_opt get_by_name_request name)

        let insert_request =
          Caqti_request.exec Model.t
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

        let insert ctx ~template =
          DbService.query ctx (fun (module Connection : Caqti_lwt.CONNECTION) ->
              Connection.exec insert_request template)

        let update_request =
          Caqti_request.exec Model.t
            {sql|
        UPDATE email_templates
        SET
          name = $2,
          content_text = $3,
          content_html = $4,
          created_at = $5
        WHERE email_templates.uuid = UNHEX(REPLACE($1, '-', ''))
        |sql}

        let update ctx ~template =
          DbService.query ctx (fun (module Connection : Caqti_lwt.CONNECTION) ->
              Connection.exec update_request template)

        let clean_request =
          Caqti_request.exec Caqti_type.unit
            {sql|
        TRUNCATE TABLE email_templates;
         |sql}

        let clean ctx =
          DbService.query ctx (fun (module Connection : Caqti_lwt.CONNECTION) ->
              Connection.exec clean_request ())
      end

      module Migration = struct
        let fix_collation =
          Data.Migration.create_step ~label:"fix collation"
            "SET collation_server = 'utf8mb4_unicode_ci'"

        let create_templates_table =
          Data.Migration.create_step ~label:"create templates table"
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

        let migration () =
          Data.Migration.(
            empty "email" |> add_step fix_collation
            |> add_step create_templates_table)
      end

      let register_migration () =
        MigrationService.register (Migration.migration ())

      let register_cleaner () = RepoService.register_cleaner Sql.clean

      let get = Sql.get

      let get_by_name = Sql.get_by_name

      let insert = Sql.insert

      let update = Sql.update
    end

    module MakePostgreSql
        (DbService : Data.Db.Sig.SERVICE)
        (RepoService : Data.Repo.Sig.SERVICE)
        (MigrationService : Data.Migration.Sig.SERVICE) :
      Email_sig.Template.REPO = struct
      module Sql = struct
        module Model = Email_core.Template

        let get_request =
          Caqti_request.find_opt Caqti_type.string Model.t
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

        let get ctx ~id =
          DbService.query ctx (fun (module Connection : Caqti_lwt.CONNECTION) ->
              Connection.find_opt get_request id)

        let get_by_name_request =
          Caqti_request.find_opt Caqti_type.string Model.t
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

        let get_by_name ctx ~name =
          DbService.query ctx (fun (module Connection : Caqti_lwt.CONNECTION) ->
              Connection.find_opt get_by_name_request name)

        let insert_request =
          Caqti_request.exec Model.t
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

        let insert ctx ~template =
          DbService.query ctx (fun (module Connection : Caqti_lwt.CONNECTION) ->
              Connection.exec insert_request template)

        let update_request =
          Caqti_request.exec Model.t
            {sql|
        UPDATE email_templates
        SET
          name = $2,
          content_text = $3,
          content_html = $4,
          created_at = $5
        WHERE email_templates.uuid = $1
        |sql}

        let update ctx ~template =
          DbService.query ctx (fun (module Connection : Caqti_lwt.CONNECTION) ->
              Connection.exec update_request template)

        let clean_request =
          Caqti_request.exec Caqti_type.unit
            "TRUNCATE TABLE email_templates CASCADE;"

        let clean ctx =
          DbService.query ctx (fun (module Connection : Caqti_lwt.CONNECTION) ->
              Connection.exec clean_request ())
      end

      module Migration = struct
        let create_templates_table =
          Data.Migration.create_step ~label:"create templates table"
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

        let migration () =
          Data.Migration.(empty "email" |> add_step create_templates_table)
      end

      let register_migration () =
        MigrationService.register (Migration.migration ())

      let register_cleaner () = RepoService.register_cleaner Sql.clean

      let get = Sql.get

      let get_by_name = Sql.get_by_name

      let insert = Sql.insert

      let update = Sql.update
    end
  end
end

module Make = struct
  module Console (TemplateService : Email_sig.Template.SERVICE) :
    Email_sig.SERVICE = struct
    module Template = TemplateService

    let lifecycle =
      Core.Container.Lifecycle.make "email"
        ~dependencies:[ TemplateService.lifecycle ]
        (fun ctx -> Lwt.return ctx)
        (fun _ -> Lwt.return ())

    let show email =
      let sender = Email_core.sender email in
      let recipient = Email_core.recipient email in
      let subject = Email_core.subject email in
      let text_content = Email_core.text_content email in
      let html_content = Email_core.html_content email in
      Printf.sprintf
        {|
-----------------------
Email sent by: %s
Recpient: %s
Subject: %s
-----------------------
Text:

%s
-----------------------
Html:

%s
-----------------------
|}
        sender recipient subject text_content html_content

    let send ctx email =
      let* email = TemplateService.render ctx email in
      let to_print = email |> show in
      Lwt.return (Caml.print_endline to_print)

    let bulk_send ctx emails =
      let rec loop emails =
        match emails with
        | email :: emails -> Lwt.bind (send ctx email) (fun _ -> loop emails)
        | [] -> Lwt.return ()
      in
      loop emails
  end

  module Smtp
      (Log : Log.Sig.SERVICE)
      (TemplateService : Email_sig.Template.SERVICE)
      (ConfigProvider : Email_sig.ConfigProvider.SMTP) : Email_sig.SERVICE =
  struct
    module Template = TemplateService

    let lifecycle =
      Core.Container.Lifecycle.make "email"
        ~dependencies:[ TemplateService.lifecycle ]
        (fun ctx -> Lwt.return ctx)
        (fun _ -> Lwt.return ())

    let send ctx email =
      (* TODO: how to get config for sending emails? *)
      let* rendered = TemplateService.render ctx email in
      let recipients =
        List.concat
          [
            [ Letters.To rendered.recipient ];
            List.map rendered.cc ~f:(fun address -> Letters.Cc address);
            List.map rendered.bcc ~f:(fun address -> Letters.Bcc address);
          ]
      in
      let body =
        match rendered.html with
        | true -> Letters.Html rendered.html_content
        | false -> Letters.Plain rendered.text_content
      in
      let* sender = ConfigProvider.sender ctx in
      let* username = ConfigProvider.username ctx in
      let* password = ConfigProvider.password ctx in
      let* hostname = ConfigProvider.host ctx in
      let* port = ConfigProvider.port ctx in
      let* with_starttls = ConfigProvider.start_tls ctx in
      let* ca_path = ConfigProvider.ca_path ctx in
      let* ca_cert = ConfigProvider.ca_cert ctx in
      let config =
        Letters.Config.make ~username ~password ~hostname ~with_starttls
        |> Letters.Config.set_port port
        |> fun conf ->
        match (ca_cert, ca_path) with
        | Some path, _ -> Letters.Config.set_ca_cert path conf
        | None, Some path -> Letters.Config.set_ca_path path conf
        | None, None -> conf
      in
      Letters.build_email ~from:email.sender ~recipients ~subject:email.subject
        ~body
      |> function
      | Ok message -> Letters.send ~config ~sender ~recipients ~message
      | Error msg -> raise (Email_core.Exception msg)

    let bulk_send _ _ = Lwt.return ()
  end

  module SendGrid
      (Log : Log_sig.SERVICE)
      (TemplateService : Email_sig.Template.SERVICE)
      (ConfigProvider : Email_sig.ConfigProvider.SENDGRID) : Email_sig.SERVICE =
  struct
    module Template = TemplateService

    let lifecycle =
      Core.Container.Lifecycle.make "email"
        ~dependencies:[ TemplateService.lifecycle ]
        (fun ctx -> Lwt.return ctx)
        (fun _ -> Lwt.return ())

    let body ~recipient ~subject ~sender ~content =
      Printf.sprintf
        {|
  {
    "personalizations": [
      {
        "to": [
          {
            "email": "%s"
          }
        ],
        "subject": "%s"
      }
    ],
    "from": {
      "email": "%s"
    },
    "content": [
       {
         "type": "text/plain",
         "value": "%s"
       }
    ]
  }
|}
        recipient subject sender content

    let sendgrid_send_url =
      "https://api.sendgrid.com/v3/mail/send" |> Uri.of_string

    let send ctx email =
      let* token = ConfigProvider.api_key ctx in
      let headers =
        Cohttp.Header.of_list
          [
            ("authorization", "Bearer " ^ token);
            ("content-type", "application/json");
          ]
      in
      let* email = TemplateService.render ctx email in
      let sender = Email_core.sender email in
      let recipient = Email_core.recipient email in
      let subject = Email_core.subject email in
      let text_content = Email_core.text_content email in
      (* TODO support html content *)
      (* let html_content = Email_core.text_content email in *)
      let req_body = body ~recipient ~subject ~sender ~content:text_content in
      let* resp, resp_body =
        Cohttp_lwt_unix.Client.post
          ~body:(Cohttp_lwt.Body.of_string req_body)
          ~headers sendgrid_send_url
      in
      let status = Cohttp.Response.status resp |> Cohttp.Code.code_of_status in
      match status with
      | 200 | 202 ->
          Log.info (fun m -> m "EMAIL: Successfully sent email using sendgrid");
          Lwt.return ()
      | _ ->
          let* body = Cohttp_lwt.Body.to_string resp_body in
          Log.err (fun m ->
              m
                "EMAIL: Sending email using sendgrid failed with http status \
                 %i and body %s"
                status body);
          raise (Email_core.Exception "EMAIL: Failed to send email")

    let bulk_send _ _ = Lwt.return ()
  end

  module Memory (TemplateService : Email_sig.Template.SERVICE) :
    Email_sig.SERVICE = struct
    module Template = TemplateService

    let lifecycle =
      Core.Container.Lifecycle.make "email"
        ~dependencies:[ TemplateService.lifecycle ]
        (fun ctx -> Lwt.return ctx)
        (fun _ -> Lwt.return ())

    let send ctx email =
      let* email = TemplateService.render ctx email in
      Email_core.DevInbox.set email;
      Lwt.return ()

    let bulk_send ctx emails =
      let rec loop emails =
        match emails with
        | email :: emails -> Lwt.bind (send ctx email) (fun _ -> loop emails)
        | [] -> Lwt.return ()
      in
      loop emails
  end
end

(** Use this functor to create an email service that sends emails using the job queue. This is useful if you need to answer a request quickly while sending the email in the background *)
module MakeDelayed
    (Log : Log.Sig.SERVICE)
    (EmailService : Email_sig.SERVICE)
    (DbService : Data.Db.Sig.SERVICE)
    (QueueService : Queue_sig.SERVICE) : Email_sig.SERVICE = struct
  module Template = EmailService.Template

  module Job = struct
    let input_to_string email =
      email |> Email_core.to_yojson |> Yojson.Safe.to_string |> Option.return

    let string_to_input email =
      match email with
      | None ->
          Log.err (fun m ->
              m
                "DELAYED_EMAIL: Serialized email string was NULL, can not \
                 deserialize email. Please fix the string manually and reset \
                 the job instance.");
          Error "Invalid serialized email string received"
      | Some email ->
          email |> Utils.Json.parse |> Result.bind ~f:Email_core.of_yojson

    let handle ctx ~input = EmailService.send ctx input |> Lwt.map Result.return

    (** Nothing to clean up, sending emails is a side effect *)
    let failed _ = Lwt_result.return ()

    let job =
      Queue_core.Job.create ~name:"send_email" ~with_context:DbService.add_pool
        ~input_to_string ~string_to_input ~handle ~failed ()
      |> Queue_core.Job.set_max_tries 10
      |> Queue_core.Job.set_retry_delay Utils.Time.OneHour
  end

  let lifecycle =
    Core.Container.Lifecycle.make "delayed-email"
      ~dependencies:
        [
          Log.lifecycle;
          EmailService.lifecycle;
          DbService.lifecycle;
          QueueService.lifecycle;
        ]
      (fun ctx ->
        QueueService.register_jobs ctx ~jobs:[ Job.job ]
        |> Lwt.map (fun () -> ctx))
      (fun _ -> Lwt.return ())

  let send ctx email = QueueService.dispatch ctx ~job:Job.job email

  let bulk_send ctx emails =
    DbService.atomic ctx (fun ctx ->
        let rec loop emails =
          match emails with
          | email :: emails -> Lwt.bind (send ctx email) (fun () -> loop emails)
          | [] -> Lwt.return ()
        in
        loop emails)
end
