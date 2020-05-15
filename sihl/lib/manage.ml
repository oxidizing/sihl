let ( let* ) = Lwt.bind

let project_ref = ref None

let start project =
  let () = project_ref := Some project in
  let* result = Run.Project.start project in
  match result with
  | Ok _ -> Lwt.return ()
  | Error msg ->
      let _ = Logs.err (fun m -> m "failed to start project: %s" msg) in
      Lwt.return ()

let stop () =
  let project = Option.get !project_ref in
  let* result = Run.Project.stop project in
  match result with
  | Ok _ -> Lwt.return ()
  | Error msg ->
      let _ = Logs.err (fun m -> m "failed to stop project: %s" msg) in
      Lwt.return ()

let clean () =
  let project = Option.get !project_ref in
  let* result = Run.Project.clean project in
  match result with
  | Ok _ -> Lwt.return ()
  | Error msg ->
      let _ = Logs.err (fun m -> m "failed to clean project: %s" msg) in
      Lwt.return ()

let migrate () =
  let project = Option.get !project_ref in
  let* result = Run.Project.migrate project in
  match result with
  | Ok _ -> Lwt.return ()
  | Error msg ->
      let _ = Logs.err (fun m -> m "failed to migrate project: %s" msg) in
      Lwt.return ()
