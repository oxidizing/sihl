let name = "cache"

exception Exception of string

module type Sig = sig
  (** [set entry] inserts an [entry] into the cache storage. [entry] is a tuple
      where the first element is the key and the second element is the value.
      Since the value is an optional, [set] can be used to remove a value from
      the store like so: [set ("foo", None)]. If a key exists already, the value
      is overwritten with the provided value. *)
  val set : string * string option -> unit Lwt.t

  (** [find key] returns the value that is associated with [key]. *)
  val find : string -> string option Lwt.t

  val register : unit -> Core_container.Service.t

  include Core_container.Service.Sig
end
