module Config = struct
  include Test_config.Base

  let database_url = "mariadb://admin:password@127.0.0.1:3306/dev"
end

let () = Sihl.Config.configure (module Test_config.Base)

include Tests.Run ()
