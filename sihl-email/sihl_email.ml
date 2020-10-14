open Lwt.Syntax
module Sig = Sihl.Email.Sig

module Template = struct
  module Make (Repo : Sig.TEMPLATE_REPO) : Sig.TEMPLATE_SERVICE = struct
    let get ctx ~id = Repo.get ctx ~id
    let get_by_name ctx ~name = Repo.get_by_name ctx ~name

    let create ctx ~name ~html ~text =
      let template = Sihl.Email.Template.make ~text ~html name in
      let* () = Repo.insert ctx ~template in
      let id = Sihl.Email.Template.id template in
      let* created = Repo.get ctx ~id in
      match created with
      | None ->
        Logs.err (fun m ->
            m "EMAIL: Could not create template %a" Sihl.Email.Template.pp template);
        raise (Sihl.Email.Exception "Could not create email template")
      | Some created -> Lwt.return created
    ;;

    let update ctx ~template =
      let* () = Repo.update ctx ~template in
      let id = Sihl.Email.Template.id template in
      let* created = Repo.get ctx ~id in
      match created with
      | None ->
        Logs.err (fun m ->
            m "EMAIL: Could not update template %a" Sihl.Email.Template.pp template);
        raise (Sihl.Email.Exception "Could not create email template")
      | Some created -> Lwt.return created
    ;;

    let render ctx email =
      let template_id = Sihl.Email.template_id email in
      let template_data = Sihl.Email.template_data email in
      let text_content = Sihl.Email.text_content email in
      let html_content = Sihl.Email.html_content email in
      let* text_content, html_content =
        match template_id with
        | Some template_id ->
          let* template = Repo.get ctx ~id:template_id in
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

    let start ctx =
      Repo.register_migration ();
      Repo.register_cleaner ();
      Lwt.return ctx
    ;;

    let stop _ = Lwt.return ()
    let lifecycle = Core.Container.Lifecycle.create "template" ~start ~stop

    let configure configuration =
      let configuration = Core.Configuration.make configuration in
      Core.Container.Service.create ~configuration lifecycle
    ;;
  end

  module Repo = struct
    module MakeMariaDb (MigrationService : Sihl.Migration.Sig.SERVICE) :
      Sig.TEMPLATE_REPO = struct
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

        let get ctx ~id =
          Database.Service.query ctx (fun (module Connection : Caqti_lwt.CONNECTION) ->
              Connection.find_opt get_request id)
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

        let get_by_name ctx ~name =
          Database.Service.query ctx (fun (module Connection : Caqti_lwt.CONNECTION) ->
              Connection.find_opt get_by_name_request name)
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

        let insert ctx ~template =
          Database.Service.query ctx (fun (module Connection : Caqti_lwt.CONNECTION) ->
              Connection.exec insert_request template)
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

        let update ctx ~template =
          Database.Service.query ctx (fun (module Connection : Caqti_lwt.CONNECTION) ->
              Connection.exec update_request template)
        ;;

        let clean_request =
          Caqti_request.exec
            Caqti_type.unit
            {sql|
        TRUNCATE TABLE email_templates;
         |sql}
        ;;

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

        let create_templates_table =
          Migration.create_step
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
          Migration.(
            empty "email" |> add_step fix_collation |> add_step create_templates_table)
        ;;
      end

      let register_migration () = MigrationService.register (Migration.migration ())
      let register_cleaner () = Repository.Service.register_cleaner Sql.clean
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

        let get ctx ~id =
          Database.Service.query ctx (fun (module Connection : Caqti_lwt.CONNECTION) ->
              Connection.find_opt get_request id)
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

        let get_by_name ctx ~name =
          Database.Service.query ctx (fun (module Connection : Caqti_lwt.CONNECTION) ->
              Connection.find_opt get_by_name_request name)
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

        let insert ctx ~template =
          Database.Service.query ctx (fun (module Connection : Caqti_lwt.CONNECTION) ->
              Connection.exec insert_request template)
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

        let update ctx ~template =
          Database.Service.query ctx (fun (module Connection : Caqti_lwt.CONNECTION) ->
              Connection.exec update_request template)
        ;;

        let clean_request =
          Caqti_request.exec Caqti_type.unit "TRUNCATE TABLE email_templates CASCADE;"
        ;;

        let clean ctx =
          Database.Service.query ctx (fun (module Connection : Caqti_lwt.CONNECTION) ->
              Connection.exec clean_request ())
        ;;
      end

      module Migration = struct
        let create_templates_table =
          Migration.create_step
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

        let migration () = Migration.(empty "email" |> add_step create_templates_table)
      end

      let register_migration () = MigrationService.register (Migration.migration ())
      let register_cleaner () = Repository.Service.register_cleaner Sql.clean
      let get = Sql.get
      let get_by_name = Sql.get_by_name
      let insert = Sql.insert
      let update = Sql.update
    end
  end
end

module Make = struct
  module Console (TemplateService : Sig.TEMPLATE_SERVICE) : Sig.SERVICE = struct
    module Template = TemplateService

    let show email =
      let sender = Sihl.Email.sender email in
      let recipient = Sihl.Email.recipient email in
      let subject = Sihl.Email.subject email in
      let text_content = Sihl.Email.text_content email in
      let html_content = Sihl.Email.html_content email in
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
        sender
        recipient
        subject
        text_content
        html_content
    ;;

    let send ctx email =
      let* email = TemplateService.render ctx email in
      let to_print = email |> show in
      Lwt.return (Caml.print_endline to_print)
    ;;

    let bulk_send ctx emails =
      let rec loop emails =
        match emails with
        | email :: emails -> Lwt.bind (send ctx email) (fun _ -> loop emails)
        | [] -> Lwt.return ()
      in
      loop emails
    ;;

    let start ctx = Lwt.return ctx
    let stop _ = Lwt.return ()

    let lifecycle =
      Core.Container.Lifecycle.create
        "email"
        ~dependencies:[ TemplateService.lifecycle ]
        ~start
        ~stop
    ;;

    let configure _ = Core.Container.Service.create lifecycle
  end

  module Smtp (TemplateService : Sig.TEMPLATE_SERVICE) : Sig.SERVICE = struct
    module Template = TemplateService

    type config =
      { sender : string
      ; username : string
      ; password : string
      ; hostname : string
      ; port : int option
      ; start_tls : bool
      ; ca_path : string option
      ; ca_cert : string option
      }

    let config sender username password hostname port start_tls ca_path ca_cert =
      { sender; username; password; hostname; port; start_tls; ca_path; ca_cert }
    ;;

    let schema =
      let open Conformist in
      make
        [ string "SMTP_SENDER"
        ; string "SMTP_USERNAME"
        ; string "SMTP_PASSWORD"
        ; string "SMTP_HOST"
        ; optional (int ~default:587 "SMTP_PORT")
        ; bool "SMTP_START_TLS"
        ; optional (string "SMTP_CA_PATH")
        ; optional (string "SMTP_CA_CERT")
        ]
        config
    ;;

    let send ctx email =
      let* rendered = TemplateService.render ctx email in
      let recipients =
        List.concat
          [ [ Letters.To rendered.recipient ]
          ; List.map (fun address -> Letters.Cc address) rendered.cc
          ; List.map (fun address -> Letters.Bcc address) rendered.bcc
          ]
      in
      let body =
        match rendered.html with
        | true -> Letters.Html rendered.html_content
        | false -> Letters.Plain rendered.text_content
      in
      let sender = (Core.Configuration.read schema).sender in
      let username = (Core.Configuration.read schema).username in
      let password = (Core.Configuration.read schema).password in
      let hostname = (Core.Configuration.read schema).hostname in
      let port = (Core.Configuration.read schema).port in
      let with_starttls = (Core.Configuration.read schema).start_tls in
      let ca_path = (Core.Configuration.read schema).ca_path in
      let ca_cert = (Core.Configuration.read schema).ca_cert in
      let config =
        Letters.Config.make ~username ~password ~hostname ~with_starttls
        |> Letters.Config.set_port port
        |> fun conf ->
        match ca_cert, ca_path with
        | Some path, _ -> Letters.Config.set_ca_cert path conf
        | None, Some path -> Letters.Config.set_ca_path path conf
        | None, None -> conf
      in
      Letters.build_email ~from:email.sender ~recipients ~subject:email.subject ~body
      |> function
      | Ok message -> Letters.send ~config ~sender ~recipients ~message
      | Error msg -> raise (Sihl.Email.Exception msg)
    ;;

    let bulk_send _ _ = Lwt.return ()
    let name = "email"
    let start ctx = Lwt.return ctx
    let stop _ = Lwt.return ()

    let lifecycle =
      Core.Container.Lifecycle.create
        name
        ~dependencies:[ TemplateService.lifecycle ]
        ~start
        ~stop
    ;;

    let configure configuration =
      let configuration = Core.Configuration.make ~schema configuration in
      Core.Container.Service.create ~configuration lifecycle
    ;;
  end

  module SendGrid
      (TemplateService : Sig.TEMPLATE_SERVICE)
      (ConfigProvider : Sig.CONFIG_PROVIDER_SENDGRID) : Sig.SERVICE = struct
    module Template = TemplateService

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
        recipient
        subject
        sender
        content
    ;;

    let sendgrid_send_url = "https://api.sendgrid.com/v3/mail/send" |> Uri.of_string

    let send ctx email =
      let* token = ConfigProvider.api_key ctx in
      let headers =
        Cohttp.Header.of_list
          [ "authorization", "Bearer " ^ token; "content-type", "application/json" ]
      in
      let* email = TemplateService.render ctx email in
      let sender = Sihl.Email.sender email in
      let recipient = Sihl.Email.recipient email in
      let subject = Sihl.Email.subject email in
      let text_content = Sihl.Email.text_content email in
      (* TODO support html content *)
      (* let html_content = Sihl.Email.text_content email in *)
      let req_body = body ~recipient ~subject ~sender ~content:text_content in
      let* resp, resp_body =
        Cohttp_lwt_unix.Client.post
          ~body:(Cohttp_lwt.Body.of_string req_body)
          ~headers
          sendgrid_send_url
      in
      let status = Cohttp.Response.status resp |> Cohttp.Code.code_of_status in
      match status with
      | 200 | 202 ->
        Logs.info (fun m -> m "EMAIL: Successfully sent email using sendgrid");
        Lwt.return ()
      | _ ->
        let* body = Cohttp_lwt.Body.to_string resp_body in
        Logs.err (fun m ->
            m
              "EMAIL: Sending email using sendgrid failed with http status %i and body %s"
              status
              body);
        raise (Sihl.Email.Exception "EMAIL: Failed to send email")
    ;;

    let bulk_send _ _ = Lwt.return ()
    let start ctx = Lwt.return ctx
    let stop _ = Lwt.return ()

    let lifecycle =
      Core.Container.Lifecycle.create
        "email"
        ~dependencies:[ TemplateService.lifecycle ]
        ~start
        ~stop
    ;;

    let configure _ = Core.Container.Service.create lifecycle
  end

  module Memory (TemplateService : Sig.TEMPLATE_SERVICE) : Sig.SERVICE = struct
    module Template = TemplateService

    let send ctx email =
      let* email = TemplateService.render ctx email in
      Sihl.Email.DevInbox.set email;
      Lwt.return ()
    ;;

    let bulk_send ctx emails =
      let rec loop emails =
        match emails with
        | email :: emails -> Lwt.bind (send ctx email) (fun _ -> loop emails)
        | [] -> Lwt.return ()
      in
      loop emails
    ;;

    let start ctx = Lwt.return ctx
    let stop _ = Lwt.return ()

    let lifecycle =
      Core.Container.Lifecycle.create
        "email"
        ~dependencies:[ TemplateService.lifecycle ]
        ~start
        ~stop
    ;;

    let configure _ = Core.Container.Service.create lifecycle
  end
end

(** Use this functor to create an email service that sends emails using the job queue.
    This is useful if you need to answer a request quickly while sending the email in the
    background *)
module MakeDelayed
    (EmailService : Sig.SERVICE)
    (DbService : Sihl.Database.Sig.SERVICE)
    (QueueService : Sihl.Queue.Sig.SERVICE) : Sig.SERVICE = struct
  module Template = EmailService.Template

  module Job = struct
    let input_to_string email =
      email |> Sihl.Email.to_yojson |> Yojson.Safe.to_string |> Option.some
    ;;

    let string_to_input email =
      match email with
      | None ->
        Logs.err (fun m ->
            m
              "DELAYED_EMAIL: Serialized email string was NULL, can not deserialize \
               email. Please fix the string manually and reset the job instance.");
        Error "Invalid serialized email string received"
      | Some email -> Result.bind (email |> Utils.Json.parse) Sihl.Email.of_yojson
    ;;

    let handle ctx ~input = EmailService.send ctx input |> Lwt.map Result.ok

    (** Nothing to clean up, sending emails is a side effect *)
    let failed _ = Lwt_result.return ()

    let job =
      Queue.create_job
        ~name:"send_email"
        ~input_to_string
        ~string_to_input
        ~handle
        ~failed
        ()
      |> Queue.set_max_tries 10
      |> Queue.set_retry_delay Utils.Time.OneHour
    ;;
  end

  let send ctx email = QueueService.dispatch ctx ~job:Job.job email

  let bulk_send ctx emails =
    DbService.atomic ctx (fun ctx ->
        let rec loop emails =
          match emails with
          | email :: emails -> Lwt.bind (send ctx email) (fun () -> loop emails)
          | [] -> Lwt.return ()
        in
        loop emails)
  ;;

  let start ctx =
    QueueService.register_jobs ctx ~jobs:[ Job.job ] |> Lwt.map (fun () -> ctx)
  ;;

  let stop _ = Lwt.return ()

  let lifecycle =
    Core.Container.Lifecycle.create
      "delayed-email"
      ~start
      ~stop
      ~dependencies:
        [ EmailService.lifecycle; DbService.lifecycle; QueueService.lifecycle ]
  ;;

  let configure _ = Core.Container.Service.create lifecycle
end
