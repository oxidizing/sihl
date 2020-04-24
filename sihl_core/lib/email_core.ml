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

let create ~sender ~recipient ~subject ~text =
  { sender; recipient; subject; text }

let replace_element str k v =
  let regexp = Str.regexp @@ "{" ^ k ^ "}" in
  Str.global_replace regexp v str

let rec render data template =
  match data with
  | [] -> template
  | (k, v) :: data -> render data @@ replace_element template k v
