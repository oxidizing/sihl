(* let ( let* ) = Lwt.bind
 *
 * let render = Email_core.render
 *
 * let last_dev_email = Email_transport.DevInbox.get
 *
 * let send _ = Lwt.return @@ Ok () *)

(* let send email =
 *   let backend =
 *     Sihl_core.Config.read_string ~default:"devinbox" "EMAIL_BACKEND"
 *   in
 *   match backend with
 *   | "smtp" -> Email_transport.Smtp.send email
 *   | "console" -> Email_transport.Console.send email
 *   | _ -> Email_transport.DevInbox.send email *)
