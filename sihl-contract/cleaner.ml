open Sihl_type

module type Sig = sig
  include Sihl_core.Container.Service.Sig

  (** Register repository cleaner function.

      A cleaner function is used during integration testing to efficiently clean
      repositories. *)
  val register_cleaner : Cleaner.t -> unit

  (** Register repository cleaner functions. *)
  val register_cleaners : Cleaner.t list -> unit

  (** Run all registered repository cleaners.

      Use this carefully, running [clean_all] leads to data loss! *)
  val clean_all : unit -> unit Lwt.t

  val register : ?cleaners:Cleaner.t list -> unit -> Sihl_core.Container.Service.t
end
