type t = Core_config.Setting.t

val register_config : Core_ctx.t -> t -> (unit, string) Result.t Lwt.t
