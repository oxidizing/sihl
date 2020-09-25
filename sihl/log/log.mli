(** Logging infrastructure. *)

(** {1 Installation}

Use the provided {!Sihl.Log.Service.Make} to create a log service that logs to stdout.

{[
module Log = Sihl.Log.Service.Make ()
]}
*)

module Service = Log_service

(** {1 Usage}

The log level can be set using [LOG_EVEL] to values: error, debug, info.

Example usage:
{[Log.debug (fun m -> m "This will be printed for LOG_LEVEL=debug and LOG_LEVEL=error");]}
{[Log.info (fun m -> m "This will be printed for LOG_LEVEL=info with an int %d and a string %d" 12 "foobar");]}
*)
