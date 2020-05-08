open Base
open Model.Email

let ( let* ) = Lwt.bind

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

  let send request
      {
        sender;
        recipient;
        subject;
        content;
        cc;
        bcc;
        html;
        template_id;
        template_data;
      } =
    let* content =
      match template_id with
      | Some template_id ->
          let (module Repository : Contract.REPOSITORY) =
            Sihl_core.Registry.get Contract.repository
          in
          let* template =
            Repository.get ~id:template_id |> Sihl_core.Db.query_db_exn request
          in
          let content = render template_data template in
          Lwt.return content
      | None -> Lwt.return content
    in
    let to_print =
      create ~sender ~recipient ~subject ~content ~cc ~bcc ~html ~template_id
        ~template_data
      |> show
    in
    Lwt.return @@ Ok (Logs.info (fun m -> m "%s" to_print))
end

module Smtp : Sihl_core.Contract.Email.EMAIL with type email = t = struct
  type email = t

  let send request
      {
        sender;
        recipient;
        subject;
        content;
        cc;
        bcc;
        html;
        template_id;
        template_data;
      } =
    let* content =
      match template_id with
      | Some template_id ->
          let (module Repository : Contract.REPOSITORY) =
            Sihl_core.Registry.get Contract.repository
          in
          let* template =
            Repository.get ~id:template_id |> Sihl_core.Db.query_db_exn request
          in
          let content = render template_data template in
          Lwt.return content
      | None -> Lwt.return content
    in
    let _ =
      create ~sender ~recipient ~subject ~content ~cc ~bcc ~html ~template_id
        ~template_data
    in
    (* TODO queue email*)
    Lwt.return @@ Error "Not implemented"
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
    Option.value_exn ~message:"no dev email found" !dev_inbox

  let send request
      {
        sender;
        recipient;
        subject;
        content;
        cc;
        bcc;
        html;
        template_id;
        template_data;
      } =
    let* content =
      match template_id with
      | Some template_id ->
          let (module Repository : Contract.REPOSITORY) =
            Sihl_core.Registry.get Contract.repository
          in
          let* template =
            Repository.get ~id:template_id |> Sihl_core.Db.query_db_exn request
          in
          let content = render template_data template in
          Lwt.return content
      | None -> Lwt.return content
    in
    let email =
      create ~sender ~recipient ~subject ~content ~cc ~bcc ~html ~template_id
        ~template_data
    in
    dev_inbox := Some email;
    Lwt.return @@ Ok ()
end

let send request email =
  let (module Email : Sihl_core.Contract.Email.EMAIL with type email = t) =
    Sihl_core.Registry.get Contract.transport
  in
  Email.send request email

let bind () =
  let backend =
    Sihl_core.Config.read_string ~default:"devinbox" "EMAIL_BACKEND"
  in
  match backend with
  | "smtp" -> Sihl_core.Registry.Binding.create Contract.transport (module Smtp)
  | "console" ->
      Sihl_core.Registry.Binding.create Contract.transport (module Console)
  | _ -> Sihl_core.Registry.Binding.create Contract.transport (module Memory)
