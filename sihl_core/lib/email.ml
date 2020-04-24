let ( let* ) = Lwt.bind

let create = Email_core.create

let render = Email_core.render

let last_dev_email = Email_transport.DevInbox.get

let send email =
  let backend = "dev_inbox" in
  match backend with
  | "smtp" -> Email_transport.Smtp.send email
  | "console" -> Email_transport.Console.send email
  | _ -> Email_transport.DevInbox.send email

let send_exn email =
  let* result = send email in
  result |> Fail.with_email |> Lwt.return
