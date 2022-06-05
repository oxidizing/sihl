let () = Sihl.Config.configure (module Test_config.Base)

include Query.Db ()
