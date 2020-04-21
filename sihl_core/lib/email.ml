open Core

type t = {
  sender : string;
  recipient : string;
  subject : string;
  text : string;
}

let show email =
  [%string
    {|
-----------------------
Email sent by: $(email.sender)
Recpient: $(email.recipient)
Subject: $(email.subject)
$(email.text)
-----------------------
|}]

let replace_element str k v =
  let regexp = Str.regexp @@ "{" ^ k ^ "}" in
  Str.global_replace regexp v str

let rec render data template =
  match data with
  | [] -> template
  | (k, v) :: data -> render data @@ replace_element template k v

let create ~sender ~recipient ~subject ~text =
  { sender; recipient; subject; text }

let dev_inbox = ref None

let send email =
  let backend = "dev_inbox" in
  match backend with
  | "console" -> Logs_lwt.info (fun m -> m "%s" (show email))
  | _ ->
      let _ = dev_inbox := Some email in
      Lwt.return ()
