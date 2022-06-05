module Config = struct
  include Test_config.Base

  let database_url = "postgresql://admin:password@127.0.0.1:5432/dev"
end

let () = Sihl.Config.configure (module Test_config.Base)

include Tests.Run ()
