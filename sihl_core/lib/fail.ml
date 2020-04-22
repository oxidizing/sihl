module Error = struct
  type t =
    | BadRequest of string
    | Database of string
    | NotAuthenticated of string
    | NoPermissions of string

  let show = function
    | BadRequest msg -> msg
    | Database msg -> msg
    | NotAuthenticated msg -> msg
    | NoPermissions msg -> msg
end

module Exception = struct
  exception BadRequest of string

  exception Database of string

  exception NotAuthenticated of string

  exception NoPermissions of string
end

let exn_of_error = function
  | Ok value -> value
  | Error (Error.BadRequest msg) -> raise @@ Exception.BadRequest msg
  | Error (Error.Database msg) -> raise @@ Exception.Database msg
  | Error (Error.NotAuthenticated msg) ->
      raise @@ Exception.NotAuthenticated msg
  | Error (Error.NoPermissions msg) -> raise @@ Exception.NoPermissions msg

let exn_of_error' result = result |> Lwt.map exn_of_error

let error_of_exn : exn -> 'a = function
  | Exception.BadRequest msg -> Error (Error.BadRequest msg)
  | Exception.Database msg -> Error (Error.Database msg)
  | Exception.NotAuthenticated msg -> Error (Error.NotAuthenticated msg)
  | Exception.NoPermissions msg -> Error (Error.NoPermissions msg)
  | _ -> Error (Error.Database "unspecified exn encountered")

let try_to_run f =
  Lwt.catch
    (fun () -> f () |> Lwt.map (fun result -> Ok result))
    (fun exn -> Lwt.return @@ error_of_exn exn)

let raise_bad_request msg = raise @@ Exception.BadRequest msg

let raise_no_permissions msg = raise @@ Exception.NoPermissions msg

let raise_not_authenticated msg = raise @@ Exception.NotAuthenticated msg

let raise_database msg = raise @@ Exception.Database msg

let with_bad_request msg result =
  match result with
  | Ok result -> result
  | Error error -> raise @@ Exception.BadRequest (msg ^ " msg= " ^ error)

let with_database msg result =
  match result with
  | Ok result -> result
  | Error error -> raise @@ Exception.Database (msg ^ " msg= " ^ error)

let with_no_permission msg result =
  match result with
  | Ok result -> result
  | Error _ -> raise @@ Exception.NoPermissions msg

let err_database msg = Error.Database msg

let err_bad_request msg = Error.BadRequest msg

let err_no_permission msg = Error.NoPermissions msg
