(** A module to manage service configurations.

    An app’s configuration is everything that is likely to vary between
    deploys (staging, production, developer environments, etc).

    This includes:

    - Resource handles to the database, Memcached, and other backing services
    - Credentials to external services such as Amazon S3 or Twitter
    - Per-deploy values such as the canonical hostname for the deploy

    (Source: {{:https://12factor.net/config} https://12factor.net/config}) *)

(** {1 Configuration} *)

exception Exception of string

type ('ctor, 'ty) schema = (string, 'ctor, 'ty) Conformist.t

(** A list of key-value pairs of strings representing the configuration key like
    SMTP_HOST and a value. *)
type data = (string * string) list

(** The configuration contains configuration data and a configuration schema. *)
type t

(** [make schema data] returns a configuration containing the configuration
    [schema] and the configuration [data]. *)
val make : ?schema:('ctor, 'ty) schema -> unit -> t

(** [empty] is an empty configuration without any schema or data. *)
val empty : t

(** [commands configurations] returns the list of CLI commands given a list of
    configurations. *)
val commands : (string * t) list -> Core_command.t list

(** {1 Storing configuration}

    Configuration might come from various sources like .env files, environment
    variables or as data provided directly to services or the app. *)

(** [store data] stores the configuration [data]. *)
val store : data -> unit

(** A configuration is a list of key-value string pairs. *)

(** {1 Reading configuration}

    Using the schema validator conformist it is easy to validate and decode
    configuration values. Conformist schemas can express a richer set of
    requirements than static types, which can be used in services to validate
    configurations at start time.

    Validating configuration when starting services can lead to run-time
    exceptions, but they occur early in the app lifecycle. This minimizes the
    feedback loop and makes sure, that services start only with valid
    configuration. *)

(** [root_path] contains the path to the project root. It reads the value of
    [ROOT_PATH]. If that environment variable is not set, it goes up directories
    until a [.git], [.hg], [.svn], [.bzr] or [_darcs] directory is found. If
    none of these are found until [/] is reached, [None] is returned. *)

val root_path : unit -> string option

(** [env_files_path] contains the path where the env files are kept. It reads
    the value of [ENV_FILES_PATH]. If that environment variable is not set,
    [root_path] is used. If no root path can be found, [None] is returned. *)

val env_files_path : unit -> string option

(** [read_env_file ()] reads an [.env] file from the directory given by
    [env_files_path] and returns the key-value pairs as [data]. If [SIHL_ENV] is
    set to [test], [.env.test] is read. Otherwise [.env] is read. If the file
    doesn't exist or the directory containing the file can't be found, [None] is
    returned.

    If you just want to access configuration values, use the read functions
    instead. Every time you call [read_env_file] the file is read from disk. *)
val read_env_file : unit -> data option

(** [load_env_file ()] reads an [.env] file using {!read_env_file} and stores
    its contents into the environment variables. *)
val load_env_file : unit -> unit

(** [load ()] calls {!load_env_file} and makes sure that [SIHL_ENV] was set. *)
val load : unit -> unit

(** [read schema] returns the decoded, statically typed version of configuration
    [t] of the [schema]. This is used in services to declaratively define a
    valid configuration.

    The configuration data [t] is merged with the environment variable and, if
    present, an .env file.

    It fails with [Exception] and prints descriptive message of invalid
    configuration. *)
val read : ('ctor, 'ty) schema -> 'ty

(** [read_string key] returns the configuration value with [key] if present. The
    function is memoized, the first call caches the returned value and
    subsequent calls are fast. *)
val read_string : string -> string option

(** [read_secret unit] returns the value of SIHL_SECRET if it is set. If
    SIHL_SECRET was not set, it fails in production and in testing or local
    development the value is set to "secret". *)
val read_secret : unit -> string

(** [read_int key] returns the configuration value with [key] if present. the
    first call caches the returned value and subsequent calls are fast. *)
val read_int : string -> int option

(** [read_bool key] returns the configuration value with [key] if present. the
    first call caches the returned value and subsequent calls are fast. *)
val read_bool : string -> bool option

(** [is_test ()] returns true if Sihl is running in a test environment, meaning
    if tests are executing parts of Sihl. *)
val is_test : unit -> bool

(** [is_development ()] returns true if Sihl is running in a local environment. *)
val is_development : unit -> bool

(** [is_production ()] returns true if Sihl is running in a production
    environment. *)
val is_production : unit -> bool

(** [require t] raises an exception if the stored configuration doesn't contain
    the configurations provided by the list of configurations [t]. *)
val require : ('ctor, 'ty) schema -> unit
