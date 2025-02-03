include Sihl.Contract.Email

let log_src = Logs.Src.create ("sihl.service." ^ Sihl.Contract.Email.name)

module Logs = (val Logs.src_log log_src : Logs.LOG)

let dev_inbox : Sihl.Contract.Email.t list ref = ref []

module DevInbox = struct
  let inbox () = !dev_inbox
  let add_to_inbox email = dev_inbox := List.cons email !dev_inbox
  let clear_inbox () = dev_inbox := []
end

let print email =
  let open Sihl.Contract.Email in
  Logs.info (fun m ->
    m
      {|
-----------------------
Email sent by: %s
Recipient: %s
Subject: %s
-----------------------
Text:

%s
-----------------------
Html:

%s
-----------------------
|}
      email.sender
      email.recipient
      email.subject
      email.text
      (Option.value ~default:"<None>" email.html))
;;

let should_intercept () =
  let is_production = Sihl.Configuration.is_production () in
  let bypass =
    Option.value
      ~default:false
      (Sihl.Configuration.read_bool "EMAIL_BYPASS_INTERCEPT")
  in
  match is_production, bypass with
  | false, true -> false
  | false, false -> true
  | true, _ -> false
;;

let intercept sender email =
  let is_development = Sihl.Configuration.is_development () in
  let console =
    Option.value
      ~default:is_development
      (Sihl.Configuration.read_bool "EMAIL_CONSOLE")
  in
  let () = if console then print email else () in
  if should_intercept ()
  then Lwt.return (DevInbox.add_to_inbox email)
  else sender email
;;

type smtp_config =
  { sender : string
  ; username : string option
  ; password : string option
  ; mechanism : string option
  ; hostname : string
  ; port : int option
  ; start_tls : bool
  ; ca_path : string option
  ; ca_cert : string option
  ; console : bool option
  }

let smtp_config
      sender
      username
      password
      mechanism
      hostname
      port
      start_tls
      ca_path
      ca_cert
      console
  =
  { sender
  ; username
  ; password
  ; mechanism
  ; hostname
  ; port
  ; start_tls
  ; ca_path
  ; ca_cert
  ; console
  }
;;

let smtp_schema =
  let open Conformist in
  make
    [ string "SMTP_SENDER"
      (* TODO wrap as pair as described in
         https://github.com/oxidizing/conformist/issues/11, once exists *)
    ; optional (string "SMTP_USERNAME")
    ; optional (string "SMTP_PASSWORD")
    ; optional (string "SMTP_MECHANISM")
    ; string "SMTP_HOST"
    ; optional (int ~default:587 "SMTP_PORT")
    ; bool "SMTP_START_TLS"
    ; optional (string "SMTP_CA_PATH")
    ; optional (string "SMTP_CA_CERT")
    ; optional (bool ~default:false "EMAIL_CONSOLE")
    ]
    smtp_config
;;

module type SmtpConfig = sig
  val fetch : unit -> smtp_config Lwt.t
end

module MakeSmtp (Config : SmtpConfig) : Sihl.Contract.Email.Sig = struct
  include DevInbox

  let send' (email : Sihl.Contract.Email.t) =
    let recipients =
      List.concat
        [ [ Letters.To email.recipient ]
        ; List.map (fun address -> Letters.Cc address) email.cc
        ; List.map (fun address -> Letters.Bcc address) email.bcc
        ]
    in
    let body =
      match email.html with
      | Some html -> Letters.Html html
      | None -> Letters.Plain email.text
    in
    let%lwt config = Config.fetch () in
    let sender = config.sender in
    let username = config.username |> CCOption.get_or ~default:"" in
    let password = config.password |> CCOption.get_or ~default:"" in
    let hostname = config.hostname in
    let port = config.port in
    let with_starttls = config.start_tls in
    let ca_path = config.ca_path in
    let ca_cert = config.ca_cert in
    let mechanism =
      CCOption.bind
        config.mechanism
        CCFun.(
          CCString.lowercase_ascii
          %> function
          | "login" -> Some Sendmail.LOGIN
          | "plain" -> Some Sendmail.PLAIN
          | _ -> None)
    in
    let config =
      Letters.Config.create
        ?mechanism
        ~username
        ~password
        ~hostname
        ~with_starttls
        ()
      |> Letters.Config.set_port port
      |> fun conf ->
      match ca_cert, ca_path with
      | Some path, _ -> Letters.Config.set_ca_cert path conf
      | None, Some path -> Letters.Config.set_ca_path path conf
      | None, None -> conf
    in
    Letters.create_email
      ~from:email.sender
      ~recipients
      ~subject:email.subject
      ~body
      ()
    |> function
    | Ok message -> Letters.send ~config ~sender ~recipients ~message
    | Error msg -> raise (Sihl.Contract.Email.Exception msg)
  ;;

  let send ?ctx:_ email = intercept send' email

  let bulk_send ?ctx:_ _ =
    failwith
      "Bulk sending with the SMTP backend not supported, please use sihl-queue"
  ;;

  let start () =
    (* Make sure that configuration is valid *)
    if Sihl.Configuration.is_production ()
    then Sihl.Configuration.require smtp_schema
    else ();
    (* If mail is intercepted, don't punish user for not providing SMTP
       credentials *)
    if should_intercept () then () else Sihl.Configuration.require smtp_schema;
    Lwt.return ()
  ;;

  let stop () = Lwt.return ()

  let lifecycle =
    Sihl.Container.create_lifecycle Sihl.Contract.Email.name ~start ~stop
  ;;

  let register () =
    let configuration = Sihl.Configuration.make ~schema:smtp_schema () in
    Sihl.Container.Service.create ~configuration lifecycle
  ;;
end

module EnvSmtpConfig = struct
  let fetch () = Lwt.return @@ Sihl.Configuration.read smtp_schema
end

module Smtp = MakeSmtp (EnvSmtpConfig)

type sendgrid_config =
  { api_key : string
  ; console : bool option
  }

let sendgrid_config api_key console = { api_key; console }

let sendgrid_schema =
  let open Conformist in
  make
    [ string "SENDGRID_API_KEY"
    ; optional (bool ~default:false "EMAIL_CONSOLE")
    ]
    sendgrid_config
;;

module type SendGridConfig = sig
  val fetch : unit -> sendgrid_config Lwt.t
end

module MakeSendGrid (Config : SendGridConfig) : Sihl.Contract.Email.Sig = struct
  include DevInbox

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

  let sendgrid_send_url =
    "https://api.sendgrid.com/v3/mail/send" |> Uri.of_string
  ;;

  let send' (email : Sihl.Contract.Email.t) =
    let open Sihl.Contract.Email in
    let%lwt config = Config.fetch () in
    let token = config.api_key in
    let headers =
      Cohttp.Header.of_list
        [ "authorization", "Bearer " ^ token
        ; "content-type", "application/json"
        ]
    in
    let sender = email.sender in
    let recipient = email.recipient in
    let subject = email.subject in
    let text_content = email.text in
    (* TODO support html content *)
    (* let html_content = Sihl.Email.text_content email in *)
    let req_body = body ~recipient ~subject ~sender ~content:text_content in
    let%lwt resp, resp_body =
      Cohttp_lwt_unix.Client.post
        ~body:(Cohttp_lwt.Body.of_string req_body)
        ~headers
        sendgrid_send_url
    in
    let status = Cohttp.Response.status resp |> Cohttp.Code.code_of_status in
    match status with
    | 200 | 202 ->
      Logs.info (fun m -> m "Successfully sent email using sendgrid");
      Lwt.return ()
    | _ ->
      let%lwt body = Cohttp_lwt.Body.to_string resp_body in
      Logs.err (fun m ->
        m
          "Sending email using sendgrid failed with http status %i and body %s"
          status
          body);
      raise (Sihl.Contract.Email.Exception "Failed to send email")
  ;;

  let send ?ctx:_ email = intercept send' email

  let bulk_send ?ctx:_ _ =
    failwith
      "bulk_send() with the Sendgrid backend is not supported, please use \
       sihl-queue"
  ;;

  let start () =
    (* Make sure that configuration is valid *)
    if Sihl.Configuration.is_production ()
    then Sihl.Configuration.require sendgrid_schema
    else ();
    (* If mail is intercepted, don't punish user for not providing SMTP
       credentials *)
    if should_intercept ()
    then ()
    else Sihl.Configuration.require sendgrid_schema;
    Lwt.return ()
  ;;

  let stop () = Lwt.return ()

  let lifecycle =
    Sihl.Container.create_lifecycle Sihl.Contract.Email.name ~start ~stop
  ;;

  let register () =
    let configuration = Sihl.Configuration.make ~schema:sendgrid_schema () in
    Sihl.Container.Service.create ~configuration lifecycle
  ;;
end

module EnvSendGridConfig = struct
  let fetch () = Lwt.return (Sihl.Configuration.read sendgrid_schema)
end

module SendGrid = MakeSendGrid (EnvSendGridConfig)

(* This is useful if you need to answer a request quickly while sending the
   email in the background *)
module Queued
    (QueueService : Sihl.Contract.Queue.Sig)
    (Email : Sihl.Contract.Email.Sig) : Sihl.Contract.Email.Sig = struct
  include DevInbox

  module Job = struct
    let input_to_string email =
      email |> Sihl.Contract.Email.to_yojson |> Yojson.Safe.to_string
    ;;

    let string_to_input email =
      let email =
        try Ok (Yojson.Safe.from_string email) with
        | _ ->
          Logs.err (fun m ->
            m
              "Serialized email string was NULL, can not deserialize email. \
               Please fix the string manually and reset the job instance.");
          Error "Invalid serialized email string received"
      in
      Result.bind email (fun email ->
        email
        |> Sihl.Contract.Email.of_yojson
        |> Option.to_result ~none:"Failed to deserialize email")
    ;;

    let handle ?ctx email =
      Lwt.catch
        (fun () -> Email.send ?ctx email |> Lwt.map Result.ok)
        (fun exn ->
           let exn_string = Printexc.to_string exn in
           Lwt.return @@ Error exn_string)
    ;;

    let job =
      Sihl.Contract.Queue.create_job
        handle
        ~max_tries:10
        ~retry_delay:(Sihl.Time.Span.hours 1)
        input_to_string
        string_to_input
        "send_email"
    ;;

    let dispatch ?ctx email = QueueService.dispatch ?ctx email job
    let dispatch_all ?ctx emails = QueueService.dispatch_all ?ctx emails job
  end

  let send ?ctx email = Job.dispatch ?ctx email
  let bulk_send ?ctx emails = Job.dispatch_all ?ctx emails
  let start () = QueueService.register_jobs [ Sihl.Contract.Queue.hide Job.job ]
  let stop () = Lwt.return ()

  let lifecycle =
    Sihl.Container.create_lifecycle
      Sihl.Contract.Email.name
      ~start
      ~stop
      ~dependencies:(fun () ->
        [ Email.lifecycle; Sihl.Database.lifecycle; QueueService.lifecycle ])
  ;;

  let register () = Sihl.Container.Service.create lifecycle
end

module Template = Template
