open Base

let ( let* ) = Lwt.bind

type fn = Core_ctx.t -> string list -> (unit, string) Result.t Lwt.t
[@@deriving show]

type t = { name : string; description : string; fn : fn } [@@deriving fields]

let description command = command.description

let create ~name ~description ~fn = { name; description; fn }

let is_testing args =
  args |> List.hd
  |> Option.map ~f:(fun str -> String.is_substring ~substring:"test.exe" str)
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
  Printf.sprintf
    {|
--------------------------------------------
This is a list of all supported commands:
%s
--------------------------------------------
|}
    command_list

let execute ctx command args =
  let fn = fn command in
  let description = description command in
  (* wait for the execution to end *)
  let result = Lwt_main.run (fn ctx args) in
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
      | "version" :: _ -> Lwt.return @@ Ok (Logs.info (fun m -> m "v0.0.1"))
      | _ -> Lwt.return @@ Error "wrong usage"

    let command = create ~name:"version" ~description:"version" ~fn
  end

  module Start = struct
    (* wait so that the server stays online *)
    let rec wait () =
      let* () = Lwt_unix.sleep 60.0 in
      wait ()

    let fn start _ args =
      match args with
      | "start" :: _ ->
          let* _ = start () in
          let* () = wait () in
          Lwt.return @@ Ok ()
      | _ -> Lwt.return @@ Error "wrong usage"

    let command start =
      create ~name:"start" ~description:"starts the project" ~fn:(fn start)
  end

  module Migrate = struct
    let fn migrate _ args =
      match args with
      | "migrate" :: _ -> migrate ()
      | _ -> Lwt.return @@ Error "wrong usage"

    let command migrate =
      create ~name:"migrate" ~description:"applies all migrations"
        ~fn:(fn migrate)
  end
end
