let ( let* ) = Lwt.bind

let project_ref = ref None

let start project =
  let _ = project_ref := Some project in
  let* result = Run.Project.start project in
  match result with
  | Ok _ -> Lwt.return ()
  | Error msg ->
      let _ = Logs.err (fun m -> m "failed to start project: %s" msg) in
      Lwt.return ()

let clean () =
  let project =
    Core.Option.value_exn ~message:"tried to clean before project was started"
      !project_ref
  in
  let* result = Run.Project.clean project in
  match result with
  | Ok _ -> Lwt.return ()
  | Error msg ->
      let _ = Logs.err (fun m -> m "failed to clean project: %s" msg) in
      Lwt.return ()

let migrate () =
  let project =
    Core.Option.value_exn ~message:"tried to migrate before project was started"
      !project_ref
  in
  let* result = Run.Project.migrate project in
  match result with
  | Ok _ -> Lwt.return ()
  | Error msg ->
      let _ = Logs.err (fun m -> m "failed to migrate project: %s" msg) in
      Lwt.return ()
