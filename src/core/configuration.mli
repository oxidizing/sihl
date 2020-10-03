(** A module to manage service configurations.

An app’s configuration is everything that is likely to vary between deploys (staging, production, developer environments, etc).

This includes:

- Resource handles to the database, Memcached, and other backing services
- Credentials to external services such as Amazon S3 or Twitter
- Per-deploy values such as the canonical hostname for the deploy

(Source: {{:https://12factor.net/config}https://12factor.net/config})

*)

(** {1 Storing configuration}

Configuration might come from various sources like .env files, environment variables or as data provided directly to services or the app.
*)

exception Exception of string

type data = (string * string) list
(** A list of key-value pairs of strings representing the configuration key like SMTP_HOSt and a value. *)

type t
(** The configuration contains configuration data and a configuration schema *)

val store : data -> unit

val make : ?schema:(unit, 'ctor, 'ty) Conformist.t -> data -> t

val empty : t

val data : t -> data

val commands : t list -> Command.t list

(** A configuration is a list of key-value string pairs. *)

(** {1 Reading configuration}

Using the schema validator conformist it is easy to validate and decode configuration values. Conformist schemas can express a richer set of requirements than static types, which can be used in services to validate configurations at start time.

Validating configuration when starting services can lead to run-time exceptions, but they occur early in the app lifecycle. This minimizes the feedback loop and makes sure, that services start only with valid configuration. *)

val read : (unit, 'ctor, 'ty) Conformist.t -> 'ty

(** [fetch schema t] returns the decoded, statically typed version of configuration [t] of the [schema]. This is used in services to declaratively define a valid configuration.

The configuration data [t] is merged with the environment variable and, if present, an .env file.

It fails with [Exception] and prints descriptive message of invalid configuration. *)

val read_string : string -> string option
(** [read_string key] returns the configuration value with [key] if present. The function is memoized, the first call caches the returned value and subsequent calls are fast. *)

val read_int : string -> int option
(** [read_int key] returns the configuration value with [key] if present. the first call caches the returned value and subsequent calls are fast. *)

val read_bool : string -> bool option
(** [read_bool key] returns the configuration value with [key] if present. the first call caches the returned value and subsequent calls are fast. *)

val is_testing : unit -> bool
(** [is_testing ()] returns true if SIHL_ENV is set to [testing] *)
