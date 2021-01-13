(** {3 Authentication}

    Authentication is the process of finding out whether someone is really who
    they claim they are. In a web framework this means taking user credentials
    like email and password and returning a user a token or a cookie.

    Two middlewares {!val:Sihl.Web.Authentication.token_middleware} and
    {!val:Sihl.Web.Authentication.session_middleware} are provided.

    Use the token middleware for JSON APIs in order to return a bearer token if
    the credentials are correct.

    Use the session middleware for classical sites to return a session cookie to
    the user if the credentials are correct.

    {[ let site = [ Sihl.Web.Authentication.session_middleware () ] ]}
    {[
      let login req =
        let open Lwt.Syntax in
        let csrf = Sihl.Web.Authentication.login req in
        let notice = Sihl.Web.Flash.find_notice req in
        let alert = Sihl.Web.Flash.find_alert req in
        let* todos, _ = Todo.search 100 in
        Lwt.return
        @@ Opium.Response.of_html (Template.page csrf todos alert notice)
      ;;
    ]} *)

val login
  :  email:string
  -> password:string
  -> Rock.Response.t
  -> Rock.Response.t

val session_middleware
  :  ?key:string
  -> ?error_handler:(Sihl_contract.User.error -> Rock.Response.t Lwt.t)
  -> unit
  -> Rock.Middleware.t

val token_middleware
  :  ?key:string
  -> ?error_handler:(Sihl_contract.User.error -> Rock.Response.t Lwt.t)
  -> unit
  -> Rock.Middleware.t
