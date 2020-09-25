(** Use this module to deal with time, dates and durations.
*)

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

val duration_of_yojson :
  Yojson.Safe.t -> duration Ppx_deriving_yojson_runtime.error_or

val pp_duration : Format.formatter -> duration -> unit

val show_duration : duration -> string

val equal_duration : duration -> duration -> bool

val duration_to_span : duration -> Ptime.span

val ptime_to_yojson : Ptime.t -> [> `String of string ]

val ptime_of_yojson : Yojson.Safe.t -> (Ptime.t, string) result

val ptime_of_date_string : string -> (Ptime.t, string) result

val ptime_to_date_string : Ptime.t -> string
