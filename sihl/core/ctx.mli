(** The service request context is a key value store that can be used to pass arbitrary
    values from one service to another within the same request. *)

(** {1 Key} *)

(** The key of a value that can be stored in the context. The type of the key has to be
    indicated explicitly. *)
type 'a key

(** [create_key ()] creates a key that can be used to store and retrieve values. The type
    needs to be indicated explicitly. *)
val create_key : unit -> 'a key

(** {3 Example}

    {[
      let string_key: string = Sihl.Core.Ctx.create_key () in
      let int_key: int = Sihl.Core.Ctx.create_key () in
      let foo_key: Foo.t = Sihl.Core.Ctx.create_key ()
    ]} *)

(** {1 Map} *)

(** The service request context is a heterogeneous map that can store values of different
    types. It is typically used to pass values to services that are either 1) only valid
    in the context of a service request or 2) whose types are hidden so that different
    service implementations of the same interface can take different values. *)
type t

(** [empty] is an empty context. *)
val empty : t

(** [add key ctx] adds a value for the [key]. If there is a value stored with the key it
    will be silently replaced. *)
val add : 'a key -> 'a -> t -> t

(** [find key ctx] returns the stored value. *)
val find : 'a key -> t -> 'a option

(** [remove key ctx] returns the context with the removed value behind the [key]. *)
val remove : 'a key -> t -> t

(** [id ctx] returns the id of the context [ctx]. The ids of the currently active and used
    contexts are unique. *)
val id : t -> string
