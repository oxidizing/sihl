let ( let* ) = Lwt.bind

module Error = struct
  type t =
    | BadRequest of string
    | Database of string
    | NotAuthenticated of string
    | NoPermissions of string
    | Email of string
    | Configuration of string
    | Server of string

  let show = function
    | BadRequest msg -> msg
    | Database msg -> msg
    | NotAuthenticated msg -> msg
    | NoPermissions msg -> msg
    | Email msg -> msg
    | Configuration msg -> msg
    | Server msg -> msg
end

module Exception = struct
  exception BadRequest of string

  exception Database of string

  exception NotAuthenticated of string

  exception NoPermissions of string

  exception Email of string

  exception Configuration of string

  exception Server of string
end

let exn_of_error = function
  | Ok value -> value
  | Error (Error.BadRequest msg) -> raise @@ Exception.BadRequest msg
  | Error (Error.Database msg) -> raise @@ Exception.Database msg
  | Error (Error.NotAuthenticated msg) ->
      raise @@ Exception.NotAuthenticated msg
  | Error (Error.NoPermissions msg) -> raise @@ Exception.NoPermissions msg
  | Error (Error.Email msg) -> raise @@ Exception.Email msg
  | Error (Error.Configuration msg) -> raise @@ Exception.Configuration msg
  | Error (Error.Server msg) -> raise @@ Exception.Server msg

let exn_of_error' result = result |> Lwt.map exn_of_error

let error_of_exn : exn -> 'a = function
  | Exception.BadRequest msg -> Error (Error.BadRequest msg)
  | Exception.Database msg -> Error (Error.Database msg)
  | Exception.NotAuthenticated msg -> Error (Error.NotAuthenticated msg)
  | Exception.NoPermissions msg -> Error (Error.NoPermissions msg)
  | Exception.Email msg -> Error (Error.Email msg)
  | Exception.Configuration msg -> Error (Error.Configuration msg)
  | Exception.Server msg -> Error (Error.Server msg)
  | _ -> Error (Error.Database "unspecified exn encountered")

let try_to_run f =
  Lwt.catch
    (fun () -> f () |> Lwt.map (fun result -> Ok result))
    (fun exn -> Lwt.return @@ error_of_exn exn)

let admin_notified_text =
  "Something went wrong, our administrators have been notified"

let raise_bad_request msg =
  Logs.warn (fun m -> m "SERVICE Bad Request: %s" msg);
  raise @@ Exception.BadRequest msg

let raise_no_permissions msg =
  Logs.warn (fun m -> m "SERVICE No Permissions: %s" msg);
  raise @@ Exception.NoPermissions "Not allowed"

let raise_not_authenticated msg =
  Logs.warn (fun m -> m "SERVICE Not Authenticated: %s" msg);
  raise @@ Exception.NotAuthenticated "Not authenticated"

let raise_database msg =
  Logs.err (fun m -> m "SERVICE Database: %s" msg);
  raise @@ Exception.Database admin_notified_text

let raise_server msg =
  Logs.err (fun m -> m "SERVICE Server: %s" msg);
  raise @@ Exception.Server admin_notified_text

let raise_configuration msg =
  Logs.err (fun m -> m "SERVICE Configuration: %s" msg);
  raise @@ Exception.Configuration msg

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

let with_email result =
  match result with
  | Ok result -> result
  | Error msg -> raise @@ Exception.Email msg

let with_configuration result =
  match result with
  | Ok result -> result
  | Error msg -> raise @@ Exception.Configuration msg

let with_not_authenticated result =
  match result with
  | Ok result -> result
  | Error msg -> raise @@ Exception.NotAuthenticated msg

let err_database msg = Error.Database msg

let err_bad_request msg = Error.BadRequest msg

let err_no_permission msg = Error.NoPermissions msg

let database ?msg result =
  let* result = result in
  match result with
  | Ok result -> Lwt.return result
  | Error error ->
      Logs.err (fun m -> m "%s" (Caqti_error.show error));
      raise
      @@ Exception.Database
           (Option.value msg ~default:"a database error occurred")
