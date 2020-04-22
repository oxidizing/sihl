open Core

let ( let* ) = Lwt.bind

type fn = Opium.Std.Request.t -> string list -> (unit, string) result Lwt.t

type t = { name : string; description : string; fn : fn } [@@deriving fields]

let description command = command.description

let create ~name ~description ~fn = { name; description; fn }

let find commands args =
  args |> List.hd
  |> Option.bind ~f:(fun name ->
         commands
         |> List.find ~f:(fun command -> String.equal command.name name))

let help commands =
  commands |> List.map ~f:description |> String.concat ~sep:"\n"

let execute command args =
  let* request = Test.request_with_connection () in
  let fn = fn command in
  let description = description command in
  let* result = fn request args in
  match result with
  | Ok _ -> Lwt.return ()
  | Error "wrong usage" ->
      let _ =
        Logs.warn (fun m -> m "Wrong usage of the command \n %s" description)
      in
      Lwt.return ()
  | Error msg ->
      let _ = Logs.err (fun m -> m "Failed to run command: %s" msg) in
      Lwt.return ()
