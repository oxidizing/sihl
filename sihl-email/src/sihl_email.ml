open Lwt.Syntax
module Core = Sihl_core
module Utils = Sihl_core.Utils
module Template = Sihl_email_template

let log_src = Logs.Src.create "sihl.service.email"

module Logs = (val Logs.src_log log_src : Logs.LOG)

let print email =
  let sender = Sihl_type.Email.sender email in
  let recipient = Sihl_type.Email.recipient email in
  let subject = Sihl_type.Email.subject email in
  let text_content = Sihl_type.Email.text_content email in
  let html_content = Sihl_type.Email.html_content email in
  Logs.info (fun m ->
      m
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
        html_content)
;;

let should_intercept () =
  let is_production = Sihl_core.Configuration.is_production () in
  let bypass =
    Option.value
      ~default:false
      (Sihl_core.Configuration.read_bool "EMAIL_BYPASS_INTERCEPT")
  in
  match is_production, bypass with
  | false, true -> false
  | false, false -> true
  | true, _ -> false
;;

let intercept sender email =
  let is_development = Sihl_core.Configuration.is_development () in
  let console =
    Option.value
      ~default:is_development
      (Sihl_core.Configuration.read_bool "EMAIL_CONSOLE")
  in
  let () = if console then print email else () in
  if should_intercept ()
  then Lwt.return (Sihl_type.Email.add_to_inbox email)
  else sender email
;;

module MakeSmtp (TemplateService : Sihl_contract.Email_template.Sig) :
  Sihl_contract.Email.Sig = struct
  type config =
    { sender : string
    ; username : string
    ; password : string
    ; hostname : string
    ; port : int option
    ; start_tls : bool
    ; ca_path : string option
    ; ca_cert : string option
    ; console : bool option
    }

  let config sender username password hostname port start_tls ca_path ca_cert console =
    { sender; username; password; hostname; port; start_tls; ca_path; ca_cert; console }
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
      ; optional (string ~default:"/etc/ssl/certs" "SMTP_CA_PATH")
      ; optional (string ~default:"" "SMTP_CA_CERT")
      ; optional (bool ~default:false "EMAIL_CONSOLE")
      ]
      config
  ;;

  let send' (email : Sihl_type.Email.t) =
    let recipients =
      List.concat
        [ [ Letters.To email.recipient ]
        ; List.map (fun address -> Letters.Cc address) email.cc
        ; List.map (fun address -> Letters.Bcc address) email.bcc
        ]
    in
    let body =
      match email.html with
      | true -> Letters.Html email.html_content
      | false -> Letters.Plain email.text_content
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
    | Error msg -> raise (Sihl_type.Email.Exception msg)
  ;;

  let send email =
    let* email = TemplateService.render email in
    intercept send' email
  ;;

  let bulk_send _ = failwith "Bulk sending not implemented yet"

  let start () =
    (* if mail is intercepted, don't punish user for not providing SMTP credentials *)
    if should_intercept () then () else Core.Configuration.require schema;
    Lwt.return ()
  ;;

  let stop () = Lwt.return ()

  let lifecycle =
    Core.Container.Lifecycle.create
      "email"
      ~dependencies:[ TemplateService.lifecycle ]
      ~start
      ~stop
  ;;

  let register () =
    let configuration = Core.Configuration.make ~schema () in
    Core.Container.Service.create ~configuration lifecycle
  ;;
end

module MakeSendGrid (TemplateService : Sihl_contract.Email_template.Sig) :
  Sihl_contract.Email.Sig = struct
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

  type config =
    { api_key : string
    ; console : bool option
    }

  let config api_key console = { api_key; console }

  let schema =
    let open Conformist in
    make [ string "SENDGRID_API_KEY"; optional (bool "EMAIL_CONSOLE") ] config
  ;;

  let send' email =
    let token = (Sihl_core.Configuration.read schema).api_key in
    let headers =
      Cohttp.Header.of_list
        [ "authorization", "Bearer " ^ token; "content-type", "application/json" ]
    in
    let sender = Sihl_type.Email.sender email in
    let recipient = Sihl_type.Email.recipient email in
    let subject = Sihl_type.Email.subject email in
    let text_content = Sihl_type.Email.text_content email in
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
      raise (Sihl_type.Email.Exception "EMAIL: Failed to send email")
  ;;

  let send email =
    let* email = TemplateService.render email in
    intercept send' email
  ;;

  let bulk_send _ = Lwt.return ()
  let start () = Lwt.return ()
  let stop () = Lwt.return ()

  let lifecycle =
    Core.Container.Lifecycle.create
      "email"
      ~dependencies:[ TemplateService.lifecycle ]
      ~start
      ~stop
  ;;

  let register () =
    let configuration = Core.Configuration.make ~schema () in
    Core.Container.Service.create ~configuration lifecycle
  ;;
end

(* Use this functor to create an email service that sends emails using the job queue. This
   is useful if you need to answer a request quickly while sending the email in the
   background *)
module MakeQueued
    (EmailService : Sihl_contract.Email.Sig)
    (QueueService : Sihl_contract.Queue.Sig) : Sihl_contract.Email.Sig = struct
  module Job = struct
    let input_to_string email =
      email |> Sihl_type.Email.to_yojson |> Yojson.Safe.to_string |> Option.some
    ;;

    let string_to_input email =
      match email with
      | None ->
        Logs.err (fun m ->
            m
              "DELAYED_EMAIL: Serialized email string was NULL, can not deserialize \
               email. Please fix the string manually and reset the job instance.");
        Error "Invalid serialized email string received"
      | Some email -> Result.bind (email |> Utils.Json.parse) Sihl_type.Email.of_yojson
    ;;

    let handle ~input = EmailService.send input |> Lwt.map Result.ok

    (** Nothing to clean up, sending emails is a side effect *)
    let failed _ = Lwt_result.return ()

    let job =
      Sihl_type.Queue_job.create
        ~name:"send_email"
        ~input_to_string
        ~string_to_input
        ~handle
        ~failed
        ()
      |> Sihl_type.Queue_job.set_max_tries 10
      |> Sihl_type.Queue_job.set_retry_delay Core.Time.OneHour
    ;;
  end

  let send email =
    (* skip queue when running tests *)
    if not (Sihl_core.Configuration.is_production ())
    then (
      Logs.debug (fun m -> m "Skipping queue for email sending");
      EmailService.send email)
    else QueueService.dispatch ~job:Job.job email
  ;;

  let bulk_send emails =
    (* TODO [jerben] Implement queue API for multiple jobs so we don't have to use
       transactions here *)
    let rec loop emails =
      match emails with
      | email :: emails -> Lwt.bind (send email) (fun () -> loop emails)
      | [] -> Lwt.return ()
    in
    loop emails
  ;;

  let start () = QueueService.register_jobs ~jobs:[ Job.job ] |> Lwt.map ignore
  let stop () = Lwt.return ()

  let lifecycle =
    Core.Container.Lifecycle.create
      "delayed-email"
      ~start
      ~stop
      ~dependencies:
        [ EmailService.lifecycle
        ; Sihl_persistence.Database.lifecycle
        ; QueueService.lifecycle
        ]
  ;;

  let register () = Core.Container.Service.create lifecycle
end

module Template_repo = Sihl_email_template_repo
