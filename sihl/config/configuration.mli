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
(** [create ~development ~test ~production] is the configuration. 

Example:

{[
let config =
  Sihl.Config.create
    ~development:
      [ ("DATABASE_URL", "mariadb://root:password@127.0.0.1:3306/dev") ]
    ~test:[ ("DATABASE_URL", "mariadb://root:password@127.0.0.1:3306/test") ]
    ~production:[]

]}
*)

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

Most services need a configuration provider in the service setup file. Let's have a look at the SMTP email service. 

{[
(* Email template service setup, is responsible for rendering emails *)
module EmailTemplateRepo =
  Sihl.Email.Service.Template.Repo.MakeMariaDb (Db) (Repo) (Migration)
module EmailTemplate = Sihl.Email.Service.Template.Make (EmailTemplateRepo)

(* The provided EnvConfigProvider reads configuratin from env variables *)
module EmailConfigProvider = Sihl.Email.Service.EnvConfigProvider

(* The email service requires a configuration provider. It uses it to 
   fetch configuration on its own. *)
module Email =
  Sihl.Email.Service.Make.Smtp(EmailTemplate, EmailConfigProvider)
]}

The type of `EmailConfigProvider` is different from service implementation to service implementation. The type of the config provider for SMTP is: 


{[
val sender : Core.Ctx.t -> (string, string) Lwt_result.t

val username : Core.Ctx.t -> (string, string) Lwt_result.t

val password : Core.Ctx.t -> (string, string) Lwt_result.t

val host : Core.Ctx.t -> (string, string) Lwt_result.t

val port : Core.Ctx.t -> (int option, string) Lwt_result.t

val start_tls : Core.Ctx.t -> (bool, string) Lwt_result.t

val ca_dir : Core.Ctx.t -> (string, string) Lwt_result.t
]}

Note that it returns the configuration asynchronously. This is not needed when reading environment variables, but it allows you to implement your own config provider that reads configuration from elsewhere in a non-blocking way.
*)

module Service = Config_service

val is_testing : unit -> bool
(** @deprecated *)

val read_string_default : default:string -> string -> string
(** @deprecated *)
