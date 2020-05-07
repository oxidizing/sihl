open Base

let ( let* ) = Lwt.bind

type t = {
  sender : string;
  recipient : string;
  subject : string;
  content : string;
  cc : string list;
  bcc : string list;
  html : bool;
  template_id : string option;
  template_data : (string * string) list;
}

let create ~sender ~recipient ~subject ~content ~cc ~bcc ~html ~template_id
    ~template_data =
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
  }

let replace_element str k v =
  let regexp = Str.regexp @@ "{" ^ k ^ "}" in
  Str.global_replace regexp v str

let render data template =
  let rec render_value data value =
    match data with
    | [] -> value
    | (k, v) :: data -> render_value data @@ replace_element value k v
  in
  render_value data (Model.Template.value template)

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

module DevInbox : sig
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
