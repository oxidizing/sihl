val get_log_level : unit -> Logs.level option
val logs_dir : unit -> string
val lwt_file_reporter : unit -> Logs.reporter

val format_reporter
  :  ?pp_header:
       (Logs.src -> Format.formatter -> Logs.level * string option -> unit)
  -> ?app:Format.formatter
  -> ?dst:Format.formatter
  -> unit
  -> Logs.reporter

val cli_reporter
  :  ?pp_header:
       (Logs.src -> Format.formatter -> Logs.level * string option -> unit)
  -> ?app:Format.formatter
  -> ?dst:Format.formatter
  -> unit
  -> Logs.reporter

val default_reporter : Logs.reporter
