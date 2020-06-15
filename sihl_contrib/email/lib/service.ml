open Base
open Sihl.Email

let ( let* ) = Lwt.bind

let render request email =
  let template_id = template_id email in
  let template_data = template_data email in
  let content = content email in
  let* content =
    match template_id with
    | Some template_id ->
        let (module Repository : Repo_sig.REPOSITORY) =
          Sihl.Core.Registry.get Bind.Repository.key
        in
        let* template =
          Repository.get ~id:template_id |> Sihl.Core.Db.query_db_exn request
        in
        let content = Template.render template_data template in
        Lwt.return content
    | None -> Lwt.return content
  in
  set_content content email |> Lwt.return

module Console : Sihl.Email.SERVICE = struct
  let show email =
    let sender = sender email in
    let recipient = recipient email in
    let subject = subject email in
    let content = content email in
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
    let* email = render request email in
    let to_print = email |> show in
    Lwt.return @@ Ok (Logs.info (fun m -> m "%s" to_print))
end

module Smtp : Sihl.Email.SERVICE = struct
  let send request email =
    let* _ = render request email in
    (* TODO implement SMTP *)
    Lwt.return @@ Error "Not implemented"
end

module SendGrid : Sihl.Email.SERVICE = struct
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
    let token = Sihl.Core.Config.read_string "SENDGRID_API_KEY" in
    let headers =
      Cohttp.Header.of_list
        [
          ("authorization", "Bearer " ^ token);
          ("content-type", "application/json");
        ]
    in
    let* email = render request email in
    let sender = sender email in
    let recipient = recipient email in
    let subject = subject email in
    let content = content email in
    let req_body = body ~recipient ~subject ~sender ~content in
    let* resp, resp_body =
      Cohttp_lwt_unix.Client.post
        ~body:(Cohttp_lwt.Body.of_string req_body)
        ~headers sendgrid_send_url
    in
    let status = Cohttp.Response.status resp |> Cohttp.Code.code_of_status in
    match status with
    | 200 | 202 ->
        Logs.info (fun m -> m "successfully sent email using sendgrid");
        Lwt.return @@ Ok ()
    | _ ->
        let* body = Cohttp_lwt.Body.to_string resp_body in
        Logs.err (fun m ->
            m
              "sending email using sendgrid failed with http status %i and \
               body %s"
              status body);
        Lwt.return @@ Error "failed to send email"
end

module Memory : sig
  include Sihl.Email.SERVICE

  val get : unit -> t
end = struct
  let dev_inbox : t option ref = ref None

  let get () =
    if Option.is_some !dev_inbox then
      Logs.err (fun m -> m "no email found in dev inbox");
    Option.value_exn ~message:"no email found in dev inbox" !dev_inbox

  let send request email =
    let* email = render request email in
    dev_inbox := Some email;
    Lwt.return @@ Ok ()
end

let send request email =
  let (module Email : Sihl.Email.SERVICE) =
    Sihl.Core.Registry.get Bind.Transport.key
  in
  Email.send request email
