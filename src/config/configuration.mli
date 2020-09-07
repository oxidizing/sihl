(** An app’s configuration is everything that is likely to vary between deploys (staging, production, developer environments, etc).

This includes:

- Resource handles to the database, Memcached, and other backing services
- Credentials to external services such as Amazon S3 or Twitter
- Per-deploy values such as the canonical hostname for the deploy

(Source: {{:https://12factor.net/config}https://12factor.net/config})

These configurations should not be hard-coded into the source code. *)

(** {1:define Define configuration} *)

type t = Config_core.t
(** The configuration type that contains configurations for development, test and production environments. Sihl reads the right configurations according to the environment variable [SIHL_ENV]. *)

val create :
  development:Config_core.key_value Base.list ->
  test:Config_core.key_value Base.list ->
  production:Config_core.key_value Base.list ->
  t
(** [create ~development ~test ~production] is the configuration. *)

(** {1 Service Installation}

Use the provided {!Sihl.Config.Service.Make} to create a config service. You need to inject a {!Sihl.Log.Service.Sig.SERVICE}. Use the default implementation provided by Sihl:

{[
module Log = Sihl.Log.Service.Make ()
module Config = Sihl.Config.Service.Make (Log)
]}

*)

(** {1 Usage}

Use the configuration service {!Sihl.Config.Service.Sig.SERVICE} to read configurations at run-time from various sources.
*)

(** {1 Configuration Provider}

TODO *)

module Service = Config_service

val is_testing : unit -> bool
(** @deprecated *)

val read_string_default : default:string -> string -> string
(** @deprecated *)
