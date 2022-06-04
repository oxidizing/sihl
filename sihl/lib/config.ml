let env_string _ = "todo"
let env_bool _ = true

module type CONFIG = sig
  val database_url : string
end
