let hello _ = Lwt.return @@ Sihl.Web.Response.of_html View.Hello.page
