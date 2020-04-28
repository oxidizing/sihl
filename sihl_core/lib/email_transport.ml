open Base

module Console : Contract.Email.TRANSPORT = struct
  let send email =
    let _ = Logs.info (fun m -> m "%s" (Email_core.show email)) in
    Lwt.return @@ Ok ()
end

module Smtp : Contract.Email.TRANSPORT = struct
  let send _ = Lwt.return @@ Error "Not implemented"
end

module DevInbox : sig
  include Contract.Email.TRANSPORT

  val get : unit -> Email_core.t
end = struct
  let dev_inbox : Email_core.t option ref = ref None

  let get () = Option.value_exn ~message:"no dev email found" !dev_inbox

  let send email =
    let _ = dev_inbox := Some email in
    Lwt.return @@ Ok ()
end
