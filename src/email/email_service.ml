open Base

let ( let* ) = Lwt_result.bind

module Template = struct
  module Make
      (MigrationService : Data.Migration.Sig.SERVICE)
      (TemplateRepo : Email_sig.Template.REPO)
      (RepoService : Data.Repo.Sig.SERVICE) : Email_sig.Template.SERVICE =
  struct
    let on_init ctx =
      let* () = MigrationService.register ctx (TemplateRepo.migrate ()) in
      RepoService.register_cleaner ctx TemplateRepo.clean

    let on_start _ = Lwt.return @@ Ok ()

    let on_stop _ = Lwt.return @@ Ok ()

    let get ctx ~id = TemplateRepo.get ~id |> Data.Db.query ctx

    let create ctx ~name ~html ~text =
      let template = Email_core.Template.make ~text ~html name in
      let* () = TemplateRepo.insert ~template |> Data.Db.query ctx in
      let id = Email_core.Template.id template in
      let* created = TemplateRepo.get ~id |> Data.Db.query ctx in
      created
      |> Result.of_option ~error:"Could not create email template"
      |> Lwt.return

    let update ctx ~template =
      let* () = TemplateRepo.insert ~template |> Data.Db.query ctx in
      let id = Email_core.Template.id template in
      let* created = TemplateRepo.get ~id |> Data.Db.query ctx in
      created
      |> Result.of_option ~error:"Could not update email template"
      |> Lwt.return

    let render ctx email =
      let template_id = Email_core.template_id email in
      let template_data = Email_core.template_data email in
      let content = Email_core.content email in
      let* content =
        match template_id with
        | Some template_id ->
            let* template =
              TemplateRepo.get ~id:template_id |> Data.Db.query ctx
            in
            let* template =
              template
              |> Result.of_option ~error:"Template with id %s not found"
              |> Lwt.return
            in
            let content = Email_core.Template.render template_data template in
            Lwt.return @@ Ok content
        | None -> Lwt.return @@ Ok content
      in
      Email_core.set_content content email |> Result.return |> Lwt.return
  end

  module Repo = struct
    module MariaDb : Email_sig.Template.REPO = struct
      module Sql = struct
        module Model = Email_core.Template

        let get connection =
          let module Connection = (val connection : Caqti_lwt.CONNECTION) in
          let request =
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
          in
          Connection.find_opt request

        let insert connection template =
          let module Connection = (val connection : Caqti_lwt.CONNECTION) in
          let request =
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
          ?,
          ?
        )
        |sql}
          in
          Connection.exec request template
          |> Lwt_result.map_err Caqti_error.show

        let update connection template =
          let module Connection = (val connection : Caqti_lwt.CONNECTION) in
          let request =
            Caqti_request.exec Model.t
              {sql|
        UPDATE SET email_templates
          name = $2,
          content_text = $3,
          content_html = $4,
          created_at = $5
        WHERE email_templates.uuid = UNHEX(REPLACE($1, '-', ''))
        |sql}
          in
          Connection.exec request template
          |> Lwt_result.map_err Caqti_error.show

        let clean connection =
          let module Connection = (val connection : Caqti_lwt.CONNECTION) in
          let request =
            Caqti_request.exec Caqti_type.unit
              {sql|
        TRUNCATE TABLE email_templates;
         |sql}
          in
          Connection.exec request () |> Lwt_result.map_err Caqti_error.show
      end

      module Migration = struct
        let fix_collation =
          Data.Migration.create_step ~label:"fix collation"
            {sql|
SET collation_server = 'utf8mb4_unicode_ci';
|sql}

        let create_templates_table =
          Data.Migration.create_step ~label:"create templates table"
            {sql|
CREATE TABLE email_templates (
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

      let migrate = Migration.migration

      let get ~id connection =
        Sql.get connection id |> Lwt_result.map_err Caqti_error.show

      let insert conn ~template = Sql.insert conn template

      let update conn ~template = Sql.update conn template

      let clean conn = Sql.clean conn
    end

    module PostgreSql : Email_sig.Template.REPO = struct
      module Sql = struct
        module Model = Email_core.Template

        let get connection =
          let module Connection = (val connection : Caqti_lwt.CONNECTION) in
          let request =
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
          in
          Connection.find_opt request

        let insert connection template =
          let module Connection = (val connection : Caqti_lwt.CONNECTION) in
          let request =
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
          ?,
          ?
        )
        |sql}
          in
          Connection.exec request template
          |> Lwt_result.map_err Caqti_error.show

        let update connection template =
          let module Connection = (val connection : Caqti_lwt.CONNECTION) in
          let request =
            Caqti_request.exec Model.t
              {sql|
        UPDATE SET email_templates
          name = $2,
          content_text = $3,
          content_html = $4,
          created_at = $5
        WHERE email_templates.uuid = $1
        |sql}
          in
          Connection.exec request template
          |> Lwt_result.map_err Caqti_error.show

        let clean connection =
          let module Connection = (val connection : Caqti_lwt.CONNECTION) in
          let request =
            Caqti_request.exec Caqti_type.unit
              {sql|
        TRUNCATE TABLE email_templates CASCADE;
         |sql}
          in
          Connection.exec request () |> Lwt_result.map_err Caqti_error.show
      end

      module Migration = struct
        let create_templates_table =
          Data.Migration.create_step ~label:"create templates table"
            {sql|
CREATE TABLE email_templates (
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

      let migrate = Migration.migration

      let get ~id connection =
        Sql.get connection id |> Lwt_result.map_err Caqti_error.show

      let clean conn = Sql.clean conn

      let insert conn ~template = Sql.insert conn template

      let update conn ~template = Sql.update conn template
    end
  end
end

module Make = struct
  module Console (TemplateService : Email_sig.Template.SERVICE) :
    Email_sig.SERVICE = struct
    let on_init req = TemplateService.on_init req

    let on_start _ = Lwt.return @@ Ok ()

    let on_stop _ = Lwt.return @@ Ok ()

    let show email =
      let sender = Email_core.sender email in
      let recipient = Email_core.recipient email in
      let subject = Email_core.subject email in
      let content = Email_core.content email in
      Printf.sprintf
        {|
-----------------------
Email sent by: %s
Recpient: %s
Subject: %s

%s
-----------------------
|}
        sender recipient subject content

    let send request email =
      let* email = TemplateService.render request email in
      let to_print = email |> show in
      Lwt.return @@ Ok (Logs.info (fun m -> m "%s" to_print))
  end

  module Smtp
      (TemplateService : Email_sig.Template.SERVICE)
      (ConfigProvider : Email_sig.ConfigProvider.SMTP) : Email_sig.SERVICE =
  struct
    let on_init req = TemplateService.on_init req

    let on_start _ = Lwt.return @@ Ok ()

    let on_stop _ = Lwt.return @@ Ok ()

    let send request email =
      let* _ = TemplateService.render request email in
      (* TODO implement SMTP *)
      Lwt.return @@ Error "Not implemented"
  end

  module SendGrid
      (TemplateService : Email_sig.Template.SERVICE)
      (ConfigProvider : Email_sig.ConfigProvider.SENDGRID) : Email_sig.SERVICE =
  struct
    let on_init req = TemplateService.on_init req

    let on_start _ = Lwt.return @@ Ok ()

    let on_stop _ = Lwt.return @@ Ok ()

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

    let send request email =
      let* token = ConfigProvider.api_key request in
      let headers =
        Cohttp.Header.of_list
          [
            ("authorization", "Bearer " ^ token);
            ("content-type", "application/json");
          ]
      in
      let* email = TemplateService.render request email in
      let sender = Email_core.sender email in
      let recipient = Email_core.recipient email in
      let subject = Email_core.subject email in
      let content = Email_core.content email in
      let req_body = body ~recipient ~subject ~sender ~content in
      let* resp, resp_body =
        Cohttp_lwt_unix.Client.post
          ~body:(Cohttp_lwt.Body.of_string req_body)
          ~headers sendgrid_send_url
        |> Lwt.map Result.return
      in
      let status = Cohttp.Response.status resp |> Cohttp.Code.code_of_status in
      match status with
      | 200 | 202 ->
          Logs.info (fun m -> m "EMAIL: Successfully sent email using sendgrid");
          Lwt.return @@ Ok ()
      | _ ->
          let* body =
            Cohttp_lwt.Body.to_string resp_body |> Lwt.map Result.return
          in
          Logs.err (fun m ->
              m
                "EMAIL: Sending email using sendgrid failed with http status \
                 %i and body %s"
                status body);
          Lwt.return @@ Error "EMAIL: Failed to send email"
  end

  module Memory (TemplateService : Email_sig.Template.SERVICE) :
    Email_sig.SERVICE = struct
    let on_init req = TemplateService.on_init req

    let on_start _ = Lwt.return @@ Ok ()

    let on_stop _ = Lwt.return @@ Ok ()

    let send request email =
      let* email = TemplateService.render request email in
      Email_core.DevInbox.set email;
      Lwt.return @@ Ok ()
  end
end
