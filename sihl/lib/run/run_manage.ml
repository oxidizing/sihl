let ( let* ) = Lwt.bind

type t = Run_project.Project.t option ref

let project_ref = ref None

let start project =
  let () = project_ref := Some project in
  let* result = Run_project.Project.start project in
  match result with
  | Ok _ -> Lwt.return @@ Ok ()
  | Error msg ->
      Logs.err (fun m -> m "MANAGER: Failed to start project %s" msg);
      failwith msg

let stop () =
  let project = Option.get !project_ref in
  let* result = Run_project.Project.stop project in
  let () = project_ref := None in
  match result with
  | Ok _ -> Lwt.return @@ Ok ()
  | Error msg ->
      Logs.err (fun m -> m "MANAGER: Failed to stop project %s" msg);
      failwith msg

let clean () =
  let project = Option.get !project_ref in
  let* result = Run_project.Project.clean project in
  match result with
  | Ok _ -> Lwt.return @@ Ok ()
  | Error msg ->
      Logs.err (fun m -> m "MANAGER: Failed to clean project %s" msg);
      failwith msg

let migrate () =
  let project = Option.get !project_ref in
  let* result = Run_project.Project.migrate project in
  match result with
  | Ok _ -> Lwt.return @@ Ok ()
  | Error msg ->
      Logs.err (fun m -> m "MANAGER: Failed to migrate project: %s" msg);
      failwith msg
