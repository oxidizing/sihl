exception Exception of string

let name = "token"

module type Sig = sig
  (** [create ?ctx ?expires_in ?secret data] returns a token that expires in
      [expires_in] with the associated data [data]. If no [expires_in] is set,
      the default is 7 days. An optional secret [secret] can be provided for the
      token signature, by default `SIHL_SECRET` is used. *)
  val create
    :  ?ctx:(string * string) list
    -> ?secret:string
    -> ?expires_in:Core_time.duration
    -> (string * string) list
    -> string Lwt.t

  (** [read ?ctx ?secret ?force token k] returns the value that is associated
      with the key [k] in the token [token]. If [force] is set, the value is
      read and returned even if the token is expired, deactivated and the
      signature is invalid. If the token is completely invalid and can not be
      read, no value is returned. An optional secret [secret] can be provided to
      override the default `SIHL_SECRET`. *)
  val read
    :  ?ctx:(string * string) list
    -> ?secret:string
    -> ?force:unit
    -> string
    -> k:string
    -> string option Lwt.t

  (** [read_all ?ctx ?secret ?force token] returns all key-value pairs
      associated with the token [token]. If [force] is set, the values are read
      and returned even if the token is expired, deactivated and the signature
      is invalid. If the token is completely invalid and can not be read, no
      value is returned. An optional secret [secret] can be provided to override
      the default `SIHL_SECRET`.*)
  val read_all
    :  ?ctx:(string * string) list
    -> ?secret:string
    -> ?force:unit
    -> string
    -> (string * string) list option Lwt.t

  (** [verify ?ctx ?secret token] returns true if the token has a valid
      structure and the signature is valid, false otherwise. An optional secret
      [secret] can be provided to override the default `SIHL_SECRET`. *)
  val verify
    :  ?ctx:(string * string) list
    -> ?secret:string
    -> string
    -> bool Lwt.t

  (** [deactivate ?ctx token] deactivates the token. Depending on the backend of
      the token service a blacklist is used to store the token. *)
  val deactivate : ?ctx:(string * string) list -> string -> unit Lwt.t

  (** [activate ?ctx token] re-activates the token. Depending on the backend of
      the token service a blacklist is used to store the token. *)
  val activate : ?ctx:(string * string) list -> string -> unit Lwt.t

  (** [is_active ?ctx token] returns true if the token is active, false if the
      token was deactivated. An expired token or a token that has an invalid
      signature is not necessarily inactive.*)
  val is_active : ?ctx:(string * string) list -> string -> bool Lwt.t

  (** [is_expired ?ctx token] returns true if the token is expired, false
      otherwise. An optional secret [secret] can be provided to override the
      default `SIHL_SECRET`. *)
  val is_expired
    :  ?ctx:(string * string) list
    -> ?secret:string
    -> string
    -> bool Lwt.t

  (** [is_valid ?ctx token] returns true if the token is not expired, active and
      the signature is valid and false otherwise. A valid token can safely be
      used. An optional secret [secret] can be provided to override the default
      `SIHL_SECRET`. *)
  val is_valid
    :  ?ctx:(string * string) list
    -> ?secret:string
    -> string
    -> bool Lwt.t

  val register : unit -> Core_container.Service.t

  include Core_container.Service.Sig
end
