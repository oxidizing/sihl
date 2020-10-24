(* This module is based on the reworked API of Opium.

   MIT License

   Copyright (c) 2019 Rudi Grinberg

   Permission is hereby granted, free of charge, to any person obtaining a copy of this
   software and associated documentation files (the "Software"), to deal in the Software
   without restriction, including without limitation the rights to use, copy, modify,
   merge, publish, distribute, sublicense, and/or sell copies of the Software, and to
   permit persons to whom the Software is furnished to do so, subject to the following
   conditions:

   The above copyright notice and this permission notice shall be included in all copies
   or substantial portions of the Software.

   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
   INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A
   PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
   HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF
   CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR
   THE USE OR OTHER DEALINGS IN THE SOFTWARE. *)

include module type of Opium_kernel.Response

val of_plain_text
  :  ?env:Opium_kernel.Hmap.t
  -> ?headers:Cohttp.Header.t
  -> ?code:Cohttp.Code.status_code
  -> string
  -> t

val of_json
  :  ?env:Opium_kernel.Hmap.t
  -> ?headers:Cohttp.Header.t
  -> ?code:Cohttp.Code.status_code
  -> Yojson.Safe.t
  -> t

val of_file : ?headers:Cohttp.Header.t -> string -> t Lwt.t
val of_response_body : Cohttp.Response.t * Cohttp_lwt.Body.t -> t
val redirect_to : ?env:Opium_kernel.Hmap.t -> ?headers:Cohttp.Header.t -> string -> t

(** {1 Decoders} *)

(** {3 [to_json]} *)

(** [to_json t] parses the body of the response [t] as a JSON structure. If the body of
    the response cannot be parsed as a JSON structure, [None] is returned. Use
    {!to_json_exn} to raise an exception instead.

    {3 Example}

    {[
      let response = Response.of_json (`Assoc [ "Hello", `String "World" ])
      let body = Response.to_json response
    ]}

    [body] will be:

    {[ `Assoc [ "Hello", `String "World" ] ]} *)
val to_json : t -> Yojson.Safe.t option Lwt.t

(** {3 [to_json_exn]} *)

(** [to_json_exn t] parses the body of the response [t] as a JSON structure. If the body
    of the response cannot be parsed as a JSON structure, an [Invalid_argument] exception
    is raised. Use {!to_json} to return an option instead. *)
val to_json_exn : t -> Yojson.Safe.t Lwt.t

(** {3 [to_plain_text]} *)

(** [to_plain_text t] parses the body of the response [t] as a string.

    {3 Example}

    {[
      let response = Response.of_plain_text "Hello world!"
      let body = Response.to_json response
    ]}

    [body] will be:

    {[ "Hello world!" ]} *)
val to_plain_text : t -> string Lwt.t

(** {1 Getters and Setters} *)

(** {3 [status]} *)

(** [status response] returns the HTTP status of the response [response]. *)
val status : t -> int

(** {3 [set_status]} *)

(** [set_status status response] returns a copy of [response] with the HTTP status set to
    [content_type]. *)
val set_status : int -> t -> t

(** {2 General Headers} *)

(** [header key t] returns the value of the header with key [key] in the response [t]. If
    multiple headers have the key [key], only the value of the first header will be
    returned. If you want to return all the values if multiple headers are found, you can
    use {!headers}. *)
val header : string -> t -> string option

(** {3 [headers]} *)

(** [headers] returns the values of all headers with the key [key] in the response [t]. If
    you want to return the value of only the first header with the key [key], you can use
    {!header}. *)
val headers : string -> t -> string list

(** {3 [add_header]} *)

(** [add_header (key, value) t] adds a header with the key [key] and the value [value] to
    the response [t]. If a header with the same key is already persent, a new header is
    appended to the list of headers regardless. If you want to add the header only if an
    header with the same key could not be found, you can use {!add_header_unless_exists}.
    See also {!add_headers} to add multiple headers. *)
val add_header : string * string -> t -> t

(** {3 [add_header_or_replace]} *)

(** [add_header_or_replace (key, value) t] adds a header with the key [key] and the value
    [value] to the response [t]. If a header with the same key already exist, its value is
    replaced by [value]. If you want to add the header only if it doesn't already exist,
    you can use {!add_header_unless_exists}. See also {!add_headers_or_replace} to add
    multiple headers. *)
val add_header_or_replace : string * string -> t -> t

(** {3 [add_header_unless_exists]} *)

(** [add_header_unless_exists (key, value) t] adds a header with the key [key] and the
    value [value] to the response [t] if an header with the same key does not already
    exist. If a header with the same key already exist, the response remains unmodified.
    If you want to add the header regardless of whether the header is already present, you
    can use {!add_header}. See also {!add_headers_unless_exists} to add multiple headers. *)
val add_header_unless_exists : string * string -> t -> t

(** {3 [add_headers]} *)

(** [add_headers headers response] adds the headers [headers] to the response [t]. The
    headers are added regardless of whether a header with the same key is already present.
    If you want to add the header only if an header with the same key could not be found,
    you can use {!add_headers_unless_exists}. See also {!add_header} to add a single
    header. *)
val add_headers : (string * string) list -> t -> t

(** {3 [add_headers_or_replace]} *)

(** [add_headers_or_replace (key, value) t] adds a headers [headers] to the response [t].
    If a header with the same key already exist, its value is replaced by [value]. If you
    want to add the header only if it doesn't already exist, you can use
    {!add_headers_unless_exists}. See also {!add_header_or_replace} to add a single
    header. *)
val add_headers_or_replace : (string * string) list -> t -> t

(** {3 [add_headers_unless_exists]} *)

(** [add_headers_unless_exists headers response] adds the headers [headers] to the
    response [t] if an header with the same key does not already exist. If a header with
    the same key already exist, the header is will not be added to the response. If you
    want to add the header regardless of whether the header is already present, you can
    use {!add_headers}. See also {!add_header_unless_exists} to add a single header. *)
val add_headers_unless_exists : (string * string) list -> t -> t

(** {3 [remove_header]} *)

(** [remove_header (key, value) t] removes all the headers with the key [key] from the
    response [t]. If no header with the key [key] exist, the response remains unmodified. *)
val remove_header : string -> t -> t

(** {2 Specific Headers} *)

(** {3 [content_type]} *)

(** [content_type response] returns the value of the header [Content-Type] of the response
    [response]. *)
val content_type : t -> string option

(** {3 [set_content_type]} *)

(** [set_content_type content_type response] returns a copy of [response] with the value
    of the header [Content-Type] set to [content_type]. *)
val set_content_type : string -> t -> t

(** {3 [etag]} *)

(** [etag response] returns the value of the header [ETag] of the response [response]. *)
val etag : t -> string option

(** {3 [set_etag]} *)

(** [set_etag etag response] returns a copy of [response] with the value of the header
    [ETag] set to [etag]. *)
val set_etag : string -> t -> t

(** {3 [location]} *)

(** [location response] returns the value of the header [Location] of the response
    [response]. *)
val location : t -> string option

(** {3 [set_location]} *)

(** [set_location location response] returns a copy of [response] with the value of the
    header [Location] set to [location]. *)
val set_location : string -> t -> t

(** {3 [cache_control]} *)

(** [cache_control response] returns the value of the header [Cache-Control] of the
    response [response]. *)
val cache_control : t -> string option

(** {3 [set_cache_control]} *)

(** [set_cache_control cache_control response] returns a copy of [response] with the value
    of the header [Cache-Control] set to [cache_control]. *)
val set_cache_control : string -> t -> t

(** {3 [cookie]} *)

(** [cookie ?signed_with key t] returns the value of the cookie with key [key] in the
    [Set-Cookie] header of the response [t]. If [signed_with] is provided, the cookies
    will be unsigned with the given Signer and only a cookie with a valid signature will
    be returned. If the response does not contain a valid [Set-Cookie] or if no cookie
    with the key [key] exist, [None] will be returned. *)
val cookie : ?signed_with:Cookie.Signer.t -> string -> t -> Cookie.t option

(** {3 [cookies]} *)

(** [cookies ?signed_with t] returns all the value of the cookies in the [Set-Cookie]
    header of the response [t]. If [signed_with] is provided, the cookies will be unsigned
    with the given Signer and only the cookies with a valid signature will be returned. If
    the response does not contain a valid [Set-Cookie], [None] will be returned. *)
val cookies : ?signed_with:Cookie.Signer.t -> t -> Cookie.t list

(** {3 [add_cookie]} *)

(** [add_cookie ?sign_with ?expires ?scope ?same_site ?secure ?http_only value t] adds a
    cookie with value [value] to the response [t]. If a cookie with the same key already
    exists, its value will be replaced with the new value of [value]. If [sign_with] is
    provided, the cookie will be signed with the given Signer. *)
val add_cookie
  :  ?sign_with:Cookie.Signer.t
  -> ?expires:Cookie.expires
  -> ?scope:Uri.t
  -> ?same_site:Cookie.same_site
  -> ?secure:bool
  -> ?http_only:bool
  -> Cookie.value
  -> t
  -> t

(** {3 [add_cookie_unless_exists]} *)

(** [add_cookie_unless_exists ?sign_with ?expires ?scope ?same_site ?secure ?http_only
    value t] adds a cookie with value [value] to the response [t]. If a cookie with the
    same key already exists, it will remain untouched. If [sign_with] is provided, the
    cookie will be signed with the given Signer. *)
val add_cookie_unless_exists
  :  ?sign_with:Cookie.Signer.t
  -> ?expires:Cookie.expires
  -> ?scope:Uri.t
  -> ?same_site:Cookie.same_site
  -> ?secure:bool
  -> ?http_only:bool
  -> Cookie.value
  -> t
  -> t

(** {3 [remove_cookie]} *)

(** [remove_cookie key t] removes the cookie of key [key] from the [Set-Cookie] header of
    the response [t]. *)
val remove_cookie : string -> t -> t
