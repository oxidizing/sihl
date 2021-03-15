type duration =
  | OneSecond
  | OneMinute
  | TenMinutes
  | OneHour
  | OneDay
  | OneWeek
  | OneMonth
  | OneYear
[@@ocaml.deprecation
  "Sihl.Time.duration is deprecated, use [Sihl.Time.Span] instead"]

val duration_to_yojson : duration -> Yojson.Safe.t
  [@@ocaml.deprecation
    "Sihl.Time.duration is deprecated, use [Sihl.Time.Span] instead"]

val duration_of_yojson
  :  Yojson.Safe.t
  -> duration Ppx_deriving_yojson_runtime.error_or
  [@@ocaml.deprecation
    "Sihl.Time.duration is deprecated, use [Sihl.Time.Span] instead"]

val pp_duration : Format.formatter -> duration -> unit
  [@@ocaml.deprecation
    "Sihl.Time.duration is deprecated, use [Sihl.Time.Span] instead"]

val show_duration : duration -> string
  [@@ocaml.deprecation
    "Sihl.Time.duration is deprecated, use [Sihl.Time.Span] instead"]

val equal_duration : duration -> duration -> bool
  [@@ocaml.deprecation
    "Sihl.Time.duration is deprecated, use [Sihl.Time.Span] instead"]

val duration_to_span : duration -> Ptime.span
  [@@ocaml.deprecation
    "Sihl.Time.duration is deprecated, use [Sihl.Time.Span] instead"]

val date_from_now : Ptime.t -> duration -> Ptime.t
  [@@ocaml.deprecation
    "Sihl.Time.duration is deprecated, use [Sihl.Time.Span] instead"]

val ptime_to_yojson : Ptime.t -> [> `String of string ]
  [@@ocaml.deprecation
    "Sihl.Time.duration is deprecated, use [Sihl.Time.Span] instead"]

val ptime_of_yojson : Yojson.Safe.t -> (Ptime.t, string) result
  [@@ocaml.deprecation "Sihl.Time.ptime* are deprecated"]

val ptime_of_date_string : string -> (Ptime.t, string) result
  [@@ocaml.deprecation "Sihl.Time.ptime* are deprecated"]

val ptime_to_date_string : Ptime.t -> string
  [@@ocaml.deprecation "Sihl.Time.ptime* are deprecated"]

module Span : sig
  val seconds : int -> Ptime.span
  val minutes : int -> Ptime.span
  val hours : int -> Ptime.span
  val days : int -> Ptime.span
  val weeks : int -> Ptime.span
end
