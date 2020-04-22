let config = Sihl_core.Config.create ()

let project = Sihl_core.Run.Project.create ~config [ (module App) ]

(* let () = Sihl_core.Run.Project.run_command project *)
