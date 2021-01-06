open Sihl_contract.Email
open Sihl_core.Container

let to_sexp { sender; recipient; subject; text; html; cc; bcc } =
  let open Sexplib0.Sexp_conv in
  let open Sexplib0.Sexp in
  let cc = List (List.cons (Atom "cc") (List.map sexp_of_string cc)) in
  let bcc = List (List.cons (Atom "bcc") (List.map sexp_of_string bcc)) in
  List
    [ List [ Atom "sender"; sexp_of_string sender ]
    ; List [ Atom "recipient"; sexp_of_string recipient ]
    ; List [ Atom "subject"; sexp_of_string subject ]
    ; List [ Atom "text"; sexp_of_string text ]
    ; List [ Atom "html"; sexp_of_option sexp_of_string html ]
    ; cc
    ; bcc
    ]
;;

let pp fmt t = Sexplib0.Sexp.pp_hum fmt (to_sexp t)

let of_yojson json =
  let open Yojson.Safe.Util in
  try
    let sender = json |> member "sender" |> to_string in
    let recipient = json |> member "recipient" |> to_string in
    let subject = json |> member "subject" |> to_string in
    let text = json |> member "text" |> to_string in
    let html = json |> member "html" |> to_string_option in
    let cc = json |> member "cc" |> to_list |> List.map to_string in
    let bcc = json |> member "bcc" |> to_list |> List.map to_string in
    Some { sender; recipient; subject; text; html; cc; bcc }
  with
  | _ -> None
;;

let to_yojson email =
  `Assoc
    [ "sender", `String email.sender
    ; "recipient", `String email.recipient
    ; "subject", `String email.subject
    ; "text", `String email.text
    ; ( "html"
      , match email.html with
        | Some html -> `String html
        | None -> `Null )
    ; "cc", `List (List.map (fun el -> `String el) email.cc)
    ; "bcc", `List (List.map (fun el -> `String el) email.bcc)
    ]
;;

let set_text text email = { email with text }
let set_html html email = { email with html }
let instance : (module Sig) option ref = ref None

let create ?html ?(cc = []) ?(bcc = []) ~sender ~recipient ~subject text =
  { sender; recipient; subject; html; text; cc; bcc }
;;

let inbox () =
  let module Service = (val unpack name instance : Sig) in
  Service.inbox ()
;;

let clear_inbox () =
  let module Service = (val unpack name instance : Sig) in
  Service.clear_inbox ()
;;

let send email =
  let module Service = (val unpack name instance : Sig) in
  Service.send email
;;

let bulk_send emails =
  let module Service = (val unpack name instance : Sig) in
  Service.bulk_send emails
;;

let lifecycle () =
  let module Service = (val unpack name instance : Sig) in
  Service.lifecycle
;;

let register implementation =
  let module Service = (val implementation : Sig) in
  instance := Some implementation;
  Service.register ()
;;
