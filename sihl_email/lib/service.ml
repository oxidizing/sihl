open Base
open Model.Email

let ( let* ) = Lwt.bind

let render request email =
  let { template_id; template_data; content; _ } = email in
  let* content =
    match template_id with
    | Some template_id ->
        let (module Repository : Contract.REPOSITORY) =
          Sihl_core.Registry.get Binding.Repository.key
        in
        let* template =
          Repository.get ~id:template_id |> Sihl_core.Db.query_db_exn request
        in
        let content = render template_data template in
        Lwt.return content
    | None -> Lwt.return content
  in
  { email with content } |> Lwt.return

module Console : Sihl_core.Contract.Email.EMAIL with type email = t = struct
  type email = t

  let show email =
    [%string
      {|
-----------------------
Email sent by: $(email.sender)
Recpient: $(email.recipient)
Subject: $(email.subject)

$(email.content)
-----------------------
|}]

  let send request email =
    let* email = render request email in
    let to_print = email |> show in
    Lwt.return @@ Ok (Logs.info (fun m -> m "%s" to_print))
end

module Smtp : Sihl_core.Contract.Email.EMAIL with type email = t = struct
  type email = t

  let send request email =
    let* email = render request email in
    let to_send =
      Netsendmail.compose ~from_addr:("", email.sender)
        ~to_addrs:[ ("", email.recipient) ] ~subject:email.subject email.content
    in
    (* TODO install sendmail and configure SMTP server *)
    Lwt.return @@ Ok (Netsendmail.sendmail ~mailer:"sendmail" to_send)
end

module SendGrid : Sihl_core.Contract.Email.EMAIL with type email = t = struct
  type email = t

  let body ~recipient ~subject ~sender ~content =
    [%string
      {|
  {
    "personalizations": [
      {
        "to": [
          {
            "email": "$(recipient)"
          }
        ],
        "subject": "$(subject)"
      }
    ],
    "from": {
      "email": "$(sender)"
    },
    "content": [
       {
         "type": "text/plain",
         "value": "$(content)"
       }
    ]
  }
|}]

  let sendgrid_send_url =
    "https://api.sendgrid.com/v3/mail/send" |> Uri.of_string

  let send request email =
    let token = Sihl_core.Config.read_string "SENDGRID_API_KEY" in
    let headers =
      Cohttp.Header.of_list
        [
          ("authorization", "Bearer " ^ token);
          ("content-type", "application/json");
        ]
    in
    let* email = render request email in
    let req_body =
      body ~recipient:email.recipient ~subject:email.subject
        ~sender:email.sender ~content:email.content
    in
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
  include Sihl_core.Contract.Email.EMAIL

  val get : unit -> t
end
with type email = t = struct
  type email = t

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
  let (module Email : Sihl_core.Contract.Email.EMAIL with type email = t) =
    Sihl_core.Registry.get Binding.Transport.key
  in
  Email.send request email
