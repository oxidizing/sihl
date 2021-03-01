let name = "cache"

exception Exception of string

module type Sig = sig
  include Sihl_core.Container.Service.Sig

  (** [set value] inserts a [value] under a key. The value is a tuple where the
      first element is the key and the second element is the value. Since key is
      an optional, [set] can be used to remove value from the store like
      [set "foo" None]. *)
  val set : string * string option -> unit Lwt.t

  (** [find key] returns the value that is associated with [key]. *)
  val find : string -> string option Lwt.t

  val register : unit -> Sihl_core.Container.Service.t
end
