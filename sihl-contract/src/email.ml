exception Exception of string

type t =
  { sender : string
  ; recipient : string
  ; subject : string
  ; text_content : string
  ; html_content : string
  ; cc : string list
  ; bcc : string list
  ; html : bool
  ; template_id : string option
  ; template_data : (string * string) list
  }
[@@deriving yojson, show, eq, make, fields]

let inbox : t list ref = ref []
let get_inbox () = !inbox
let add_to_inbox email = inbox := List.cons email !inbox
let clear_inbox () = inbox := []
let set_text_content text_content email = { email with text_content }
let set_html_content html_content email = { email with html_content }
