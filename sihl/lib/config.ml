let env_string _ = "todo"
let env_bool _ = true

module type CONFIG = sig
  val database_url : string
end

let config = ref None

let get_config () =
  match !config with
  | Some config -> config
  | None -> failwith "config has not been initialized"
;;

let database_url () =
  let module Config = (val get_config () : CONFIG) in
  Uri.of_string Config.database_url
;;

let configure (module Config : CONFIG) = config := Some (module Config)
