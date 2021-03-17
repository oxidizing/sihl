(* This implementation is based on
   https://github.com/rgrinberg/opium/blob/master/opium/src/middlewares/middleware_debugger.ml
   but it removes the detailed error message to prevent leaking information. *)

let log_src = Logs.Src.create "sihl.middleware.error"

module Logs = (val Logs.src_log log_src : Logs.LOG)

let style =
  {|/*! normalize.css v8.0.1 | MIT License | github.com/necolas/normalize.css */html{line-height:1.15;-webkit-text-size-adjust:100%}body{margin:0}code,pre{font-family:monospace,monospace;font-size:1em}[type=button],[type=reset],[type=submit]{-webkit-appearance:button}[type=button]::-moz-focus-inner,[type=reset]::-moz-focus-inner,[type=submit]::-moz-focus-inner{border-style:none;padding:0}[type=button]:-moz-focusring,[type=reset]:-moz-focusring,[type=submit]:-moz-focusring{outline:1px dotted ButtonText}[type=checkbox],[type=radio]{box-sizing:border-box;padding:0}[type=number]::-webkit-inner-spin-button,[type=number]::-webkit-outer-spin-button{height:auto}[type=search]{-webkit-appearance:textfield;outline-offset:-2px}[type=search]::-webkit-search-decoration{-webkit-appearance:none}::-webkit-file-upload-button{-webkit-appearance:button;font:inherit}[hidden]{display:none}h2,h3,pre{margin:0}html{font-family:system-ui,-apple-system,BlinkMacSystemFont,Segoe UI,Roboto,Helvetica Neue,Arial,Noto Sans,sans-serif,Apple Color Emoji,Segoe UI Emoji,Segoe UI Symbol,Noto Color Emoji;line-height:1.5}*,:after,:before{box-sizing:border-box;border:0 solid #e2e8f0}[role=button]{cursor:pointer}h2,h3{font-size:inherit;font-weight:inherit}code,pre{font-family:Menlo,Monaco,Consolas,Liberation Mono,Courier New,monospace}.bg-white{--bg-opacity:1;background-color:#fff;background-color:rgba(255,255,255,var(--bg-opacity))}.bg-gray-500{--bg-opacity:1;background-color:#a0aec0;background-color:rgba(160,174,192,var(--bg-opacity))}.bg-gray-800{--bg-opacity:1;background-color:#2d3748;background-color:rgba(45,55,72,var(--bg-opacity))}.border-gray-200{--border-opacity:1;border-color:#edf2f7;border-color:rgba(237,242,247,var(--border-opacity))}.border-t{border-top-width:1px}.border-b{border-bottom-width:1px}.block{display:block}.inline-block{display:inline-block}.flex{display:flex}.items-center{align-items:center}.justify-between{justify-content:space-between}.font-semibold{font-weight:600}.text-sm{font-size:.875rem}.text-base{font-size:1rem}.text-2xl{font-size:1.5rem}.leading-8{line-height:2rem}.leading-snug{line-height:1.375}.leading-normal{line-height:1.5}.m-0{margin:0}.mx-auto{margin-left:auto;margin-right:auto}.mt-0{margin-top:0}.mb-4{margin-bottom:1rem}.mt-6{margin-top:1.5rem}.overflow-auto{overflow:auto}.overflow-hidden{overflow:hidden}.scrolling-touch{-webkit-overflow-scrolling:touch}.p-0{padding:0}.p-4{padding:1rem}.py-2{padding-top:.5rem;padding-bottom:.5rem}.py-4{padding-top:1rem;padding-bottom:1rem}.px-4{padding-left:1rem;padding-right:1rem}.relative{position:relative}.text-white{--text-opacity:1;color:#fff;color:rgba(255,255,255,var(--text-opacity))}.text-gray-600{--text-opacity:1;color:#718096;color:rgba(113,128,150,var(--text-opacity))}.text-gray-900{--text-opacity:1;color:#1a202c;color:rgba(26,32,44,var(--text-opacity))}.antialiased{-webkit-font-smoothing:antialiased;-moz-osx-font-smoothing:grayscale}.subpixel-antialiased{-webkit-font-smoothing:auto;-moz-osx-font-smoothing:auto}.truncate{overflow:hidden;text-overflow:ellipsis;white-space:nowrap}@media (min-width:640px){.sm\:rounded-lg{border-radius:.5rem}.sm\:border{border-width:1px}.sm\:items-baseline{align-items:baseline}.sm\:text-3xl{font-size:1.875rem}.sm\:leading-9{line-height:2.25rem}.sm\:py-4{padding-top:1rem;padding-bottom:1rem}.sm\:px-6{padding-left:1.5rem;padding-right:1.5rem}.sm\:py-12{padding-top:3rem;padding-bottom:3rem}}@media (min-width:768px){.md\:text-lg{font-size:1.125rem}}@media (min-width:1024px){.lg\:px-8{padding-left:2rem;padding-right:2rem}}|}
;;

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
    style
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

let exn_to_string exn req =
  let msg = Printexc.to_string exn
  and stack = Printexc.get_backtrace () in
  let request_id = Web_id.find req |> Option.value ~default:"-" in
  let req_str = Format.asprintf "%a" Opium.Request.pp_hum req in
  Format.asprintf
    "Request id %s: %s\nError: %s\nStacktrace: %s"
    request_id
    req_str
    msg
    stack
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
        (* Make sure to Lwt.catch everything that might go wrong. *)
        (* Log the error *)
        let error = exn_to_string exn req in
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
                Logs.err (fun m -> m "Failed to report error per email: %s" msg);
                Lwt.return ())
          | _ -> Lwt.return ()
        in
        (* Use custom reporter to catch error, don't wait for it. *)
        let _ =
          Lwt.catch
            (fun () -> reporter req error)
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
