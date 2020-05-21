open Base

let ok_json_string = {|{"msg":"ok"}|}

let ( let* ) = Lwt.bind

let url path = "http://localhost:3000/sessions" ^ path

let test_fetch_any_endpoint_creates_anonymous_session _ () = Lwt.return @@ ()
