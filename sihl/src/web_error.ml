(* This implementation is based on
   https://github.com/rgrinberg/opium/blob/master/opium/src/middlewares/middleware_debugger.ml
   but it removes the detailed error message to prevent leaking information. *)

let log_src = Logs.Src.create "sihl.middleware.error"

module Logs = (val Logs.src_log log_src : Logs.LOG)

let page request_id =
  Format.asprintf
    {|
<!doctype html>
<html lang="en">

<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1, shrink-to-fit=no">
  <title>Internal Server Error</title>
  <style>
    %s
  </style>
</head>

<body class="antialiased">
  <div class="py-4 sm:py-12">
    <div class="max-w-8xl mx-auto px-4 sm:px-6 lg:px-8">
      <h2 class="text-2xl leading-8 font-semibold font-display text-gray-900 sm:text-3xl sm:leading-9">
        Internal Server Error
      </h2>
      <div class="mt-0 mb-4 text-gray-600">
        An error has been caught while handling the request.
      </div>
      <p>
        Our administrators have been notified. Please note your request ID <b>%s</b> when contacting us.
      </p>
    </div>
  </div>
</body>

</html>
    |}
    Web.style
    request_id
;;

let site_error_handler req =
  let request_id = Web_id.find req |> Option.value ~default:"-" in
  let site = page request_id in
  Opium.Response.of_plain_text site
  |> Opium.Response.set_content_type "text/html; charset=utf-8"
  |> Lwt.return
;;

let json_error_handler req =
  let request_id = Web_id.find req |> Option.value ~default:"-" in
  let msg =
    Format.sprintf
      "Something went wrong, our administrators have been notified."
  in
  let body =
    Format.sprintf {|"{"errors": ["%s"], "request_id": "%s"}"|} msg request_id
  in
  Opium.Response.of_plain_text body
  |> Opium.Response.set_content_type "application/json; charset=utf-8"
  |> Opium.Response.set_status `Internal_server_error
  |> Lwt.return
;;

type report =
  { exn : string
  ; stack : string
  ; req_id : string
  ; req : string
  }

let report exn req =
  let stack = Printexc.get_backtrace () in
  let req_id = Web_id.find req |> Option.value ~default:"-" in
  let req = Format.asprintf "%a" Opium.Request.pp_hum req in
  let exn = Printexc.to_string exn in
  { exn; stack; req_id; req }
;;

let exn_to_string exn =
  Format.asprintf
    "Request id %s: %s\nError: %s\nStacktrace: %s"
    exn.req_id
    exn.req
    exn.exn
    exn.stack
;;

let create_error_email (sender, recipient) error =
  Contract_email.create ~sender ~recipient ~subject:"Exception caught" error
;;

let middleware
      ?email_config
      ?(reporter = fun _ _ -> Lwt.return ())
      ?error_handler
      ()
  =
  let filter handler req =
    Lwt.catch
      (fun () -> handler req)
      (fun exn ->
         let report = report exn req in
         (* Make sure to Lwt.catch everything that might go wrong. *)
         (* Log the error *)
         let error = exn_to_string report in
         Logs.err (fun m -> m "%s" error);
         (* Report error via email, don't wait for it.*)
         let _ =
           match email_config with
           | Some (sender, recipient, send_fn) ->
             let email = create_error_email (sender, recipient) error in
             Lwt.catch
               (fun () -> send_fn email)
               (fun exn ->
                  let msg = Printexc.to_string exn in
                  Logs.err (fun m ->
                    m "Failed to report error per email: %s" msg);
                  Lwt.return ())
           | _ -> Lwt.return ()
         in
         (* Use custom reporter to catch error, don't wait for it. *)
         let _ =
           Lwt.catch
             (fun () -> reporter req report)
             (fun exn ->
                let msg = Printexc.to_string exn in
                Logs.err (fun m ->
                  m "Failed to run custom error reporter: %s" msg);
                Lwt.return ())
         in
         let content_type =
           try
             req
             |> Opium.Request.header "Content-Type"
             |> Option.map (String.split_on_char ';')
             |> Option.map List.hd
           with
           | _ -> None
         in
         match error_handler with
         | Some error_handler -> error_handler req
         | None ->
           (match content_type with
            | Some "application/json" -> json_error_handler req
            (* Default to text/html *)
            | _ -> site_error_handler req))
  in
  (* In a production setting we don't want to use the built in debugger
     middleware of opium. It is useful for development but it exposed too much
     information. *)
  if Core_configuration.is_production ()
  then Rock.Middleware.create ~name:"error" ~filter
  else Opium.Middleware.debugger
;;
