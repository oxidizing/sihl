open Command_pure
(* TODO Install the right version of esbuild open Lwt.Syntax open Cohttp_lwt
   open Cohttp_lwt_unix

   let download (uri : Uri.t) (dest : string) = let* _resp, body = Client.get
   uri in (* TODO: check response for status codes, follow redirects if
   applicable *) let stream = Body.to_stream body in Lwt_io.with_file
   ~mode:Lwt_io.output dest (fun chan -> Lwt_stream.iter_s (Lwt_io.write chan)
   stream) *)

let fn _ = ()

let t : t =
  { name = "static"
  ; description = "Builds, minifies and bundles the static files"
  ; usage = "sihl static"
  ; fn
  ; stateful = false
  }
;;

let install : t =
  { name = "static.install"
  ; description = "Installs the esbuild binary"
  ; usage = "sihl static.install"
  ; fn
  ; stateful = false
  }
;;
