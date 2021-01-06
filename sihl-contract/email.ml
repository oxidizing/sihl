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
  include Sihl_core.Container.Service.Sig

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

  val register : unit -> Sihl_core.Container.Service.t
end
