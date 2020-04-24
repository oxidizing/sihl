open Core

let ( let* ) = Lwt.bind

type fn = Opium.Std.Request.t -> string list -> (unit, string) result Lwt.t

type t = { name : string; description : string; fn : fn } [@@deriving fields]

let description command = command.description

let create ~name ~description ~fn = { name; description; fn }

let is_testing args =
  args |> List.hd
  |> Option.map ~f:(fun str -> String.is_substring ~substring:"text.exe" str)
  |> Option.value_map ~default:false ~f:(fun _ -> true)

let find commands args =
  args |> List.hd
  |> Option.bind ~f:(fun name ->
         commands
         |> List.find ~f:(fun command -> String.equal command.name name))

let help commands =
  let command_list =
    commands |> List.map ~f:description |> String.concat ~sep:"\n"
  in
  [%string
    {|
--------------------------------------------
This is a list of all supported commands: 
$(command_list)
--------------------------------------------
|}]

let execute command args =
  let* request = Test.request_with_connection () in
  let fn = fn command in
  let description = description command in
  let* result = fn request args in
  match result with
  | Ok _ -> Lwt.return ()
  | Error "wrong usage" ->
      Lwt.return
      @@ Logs.warn (fun m -> m "Wrong usage of the command \n %s" description)
  | Error msg ->
      Lwt.return @@ Logs.err (fun m -> m "Failed to run command: %s" msg)

module Builtin = struct
  module Version = struct
    let fn _ args =
      match args with
      | "version" :: _ -> Lwt.return @@ Ok (print_string "v0.0.1")
      | _ -> Lwt.return @@ Error "wrong usage"

    let command = create ~name:"version" ~description:"version" ~fn
  end

  module Start = struct
    let fn start _ args =
      match args with
      | "start" :: _ -> start ()
      | _ -> Lwt.return @@ Error "wrong usage"

    let command start = create ~name:"start" ~description:"start" ~fn:(fn start)
  end
end
