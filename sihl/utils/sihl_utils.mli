(** A collection of services and libraries that deal with JWT, Json, Regex, Hashing, Time
    and Strings. *)

(** {1 Time} *)

module Time : sig
  (** Use this module to deal with time, dates and durations. *)

  type duration =
    | OneSecond
    | OneMinute
    | TenMinutes
    | OneHour
    | OneDay
    | OneWeek
    | OneMonth
    | OneYear

  val duration_to_yojson : duration -> Yojson.Safe.t
  val duration_of_yojson : Yojson.Safe.t -> duration Ppx_deriving_yojson_runtime.error_or
  val pp_duration : Format.formatter -> duration -> unit
  val show_duration : duration -> string
  val equal_duration : duration -> duration -> bool
  val duration_to_span : duration -> Ptime.span
  val ptime_to_yojson : Ptime.t -> [> `String of string ]
  val ptime_of_yojson : Yojson.Safe.t -> (Ptime.t, string) result
  val ptime_of_date_string : string -> (Ptime.t, string) result
  val ptime_to_date_string : Ptime.t -> string
end

(** {1 JSON Web Token}

    {!Sihl.Utils.Jwt} *)

module Jwt : sig
  (** This module implements JSON Web tokens. They are typically used decouple
      authentication from the other parts of a system. *)

  type algorithm = Jwto.algorithm =
    | HS256
    | HS512
    | Unknown

  type t = Jwto.t
  type payload

  val empty : payload
  val add_claim : key:string -> value:string -> payload -> payload

  (** Adds the "exp" claim. *)
  val set_expires_in : now:Ptime.t -> Time.duration -> payload -> payload

  val encode : algorithm -> secret:string -> payload -> (string, string) result

  (** Checks whether the signature is correct and decodes the base64 string representation
      to [t]. *)
  val decode : secret:string -> string -> (t, string) result

  val get_claim : key:string -> t -> string option

  (** Checks whether the [claim] of the token [t] is in the past by looking at [now]. If
      no exp claim was not found the token can not expire and [is_expired] returns true. A
      custom [claim] can be provided, by default it looks for "exp".*)
  val is_expired : now:Ptime.t -> ?claim:string -> t -> bool

  val pp : Format.formatter -> t -> unit
  val eq : t -> t -> bool

  module Jwto = Jwto
end

(** {1 JSON} *)

module Json : sig
  (** Parsing, decoding and encoding JSON. *)
  type t = Yojson.Safe.t

  val parse : string -> (t, string) result
  val parse_opt : string -> t option
  val parse_exn : string -> t
  val to_string : ?buf:Bi_outbuf.t -> ?len:int -> ?std:bool -> t -> string

  module Yojson = Yojson.Safe
end

(** {1 Regex} *)

module Regex : sig
  (** This module implements regex and exposes a high-level API for the most common use
      cases. *)

  type t = Re.Pcre.regexp

  val of_string : string -> t
  val test : t -> string -> bool
  val extract_last : t -> string -> string option

  module Re = Re
end

(** {1 Hashing} *)

module Hashing : sig
  (** Hashing strings and comparing hashes. *)

  val hash : ?count:int -> string -> (string, string) Result.t
  val matches : hash:string -> plain:string -> bool

  module Bcrypt = Bcrypt
end

(** {1 String} *)

module String : sig
  (** Helper for dealing with strings. *)

  (** [strip_chars str chars] removes all occurrences of every char in [chars] from [str]
      returns the result. *)
  val strip_chars : string -> string -> string
end

(** {1 Encryption} *)

module Encryption : sig
  (** Encrypting plaintexts and ciphertext manipulation *)

  (** [xor b1 b2] does bitwise XORing of [b1] and [b2]. Returns [None] if non-ASCII
      characters are used or the two lists differ in length. *)
  val xor : char list -> char list -> char list option

  val decrypt_with_salt : salted_cipher:char list -> salt_length:int -> char list option

  (** [decrypt_with_salt ~salted_cipher ~salt_length] splits the prepended salt off of
      [salted_cipher] and uses it to XOR the rest of [salted_cipher]. Since [xor] is used,
      returns [None] if the cipher and [salt_length] differ in length. *)
end
