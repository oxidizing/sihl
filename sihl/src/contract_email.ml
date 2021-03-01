type t =
  { sender : string
  ; recipient : string
  ; subject : string
  ; text : string
  ; html : string option
  ; cc : string list
  ; bcc : string list
  }

let name = "email"

exception Exception of string

module type Sig = sig
  (** [inbox ()] returns the content of the development in-memory mailbox.
      Intercepted emails land here, they can be used during testing to make sure
      that certain emails were sent. *)
  val inbox : unit -> t list

  (** [clear_inbox ()] removes all the emails from the development in-memory
      mailbox. A subsequent call on `inbox ()` will return an empty list. *)
  val clear_inbox : unit -> unit

  (** [send email] sends the email [email]. The returned Lwt.t fulfills if the
      underlying email transport acknowledges sending. In case of SMTP, this
      might take a while. *)
  val send : t -> unit Lwt.t

  (** [bulk_send emails] Sends the list of emails [emails]. If sending of one of
      them fails, the returned Lwt.t fails. *)
  val bulk_send : t list -> unit Lwt.t

  val register : unit -> Core_container.Service.t

  include Core_container.Service.Sig
end

(* Common functions and combinators *)

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

let create ?html ?(cc = []) ?(bcc = []) ~sender ~recipient ~subject text =
  { sender; recipient; subject; html; text; cc; bcc }
;;
