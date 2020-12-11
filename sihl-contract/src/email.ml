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

(* Signature *)
let name = "sihl.service.email"

exception Exception of string

module type Sig = sig
  include Sihl_core.Container.Service.Sig

  (** Send email. *)
  val send : t -> unit Lwt.t

  (** Send multiple emails. If sending of one of them fails, the function fails.*)
  val bulk_send : t list -> unit Lwt.t

  val register : unit -> Sihl_core.Container.Service.t
end
