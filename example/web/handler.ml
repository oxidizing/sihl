let hello_page _ = Lwt.return @@ Opium.Response.of_plain_text "Hello"
