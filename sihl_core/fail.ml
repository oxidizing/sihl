module Error = struct
  type t =
    | BadRequest of string
    | Database of string
    | NotAuthenticated of string
    | NoPermission of string

  let show = function
    | BadRequest msg -> msg
    | Database msg -> msg
    | NotAuthenticated msg -> msg
    | NoPermission msg -> msg
end

module Exception = struct
  exception BadRequest of string

  exception Database of string

  exception NotAuthenticated of string

  exception NoPermission of string
end

let exn_of_error = function
  | Ok value -> value
  | Error (Error.BadRequest msg) -> raise @@ Exception.BadRequest msg
  | Error (Error.Database msg) -> raise @@ Exception.Database msg
  | Error (Error.NotAuthenticated msg) ->
      raise @@ Exception.NotAuthenticated msg
  | Error (Error.NoPermission msg) -> raise @@ Exception.NoPermission msg

let exn_of_error' result = result |> Lwt.map exn_of_error

let error_of_exn f =
  try f () with
  | Exception.BadRequest msg -> Error (Error.BadRequest msg)
  | Exception.Database msg -> Error (Error.Database msg)
  | Exception.NotAuthenticated msg -> Error (Error.NotAuthenticated msg)
  | Exception.NoPermission msg -> Error (Error.NoPermission msg)

let raise_bad_request msg = raise @@ Exception.BadRequest msg

let map_bad_request msg result =
  result
  |> Lwt_result.map_err (fun error -> Error.BadRequest (error ^ " msg=" ^ msg))

let err_database msg = Error.Database msg
