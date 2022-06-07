let () = Sihl.Config.configure (module Test_config.Base)

include Tests.All ()
