open Opium.Std

(* HTML generation library *)
open Tyxml

(** The route handlers for our app *)

(** Defines a handler that replies to GET requests at the root endpoint *)
let root = get "/" (fun _req -> respond' @@ Content.welcome_page)

(** Defines a handler that takes a path parameter from the route *)
let hello =
  get "/hello/:lang" (fun req ->
      let lang = param req "lang" in
      respond' @@ Content.hello_page lang)

(** Fallback handler in case the endpoint is called without a language parameter *)
let hello_fallback =
  get "/hello" (fun _req ->
      respond' @@ Content.basic_page Html.[ p [ txt "Hiya" ] ])

let get_excerpts_add =
  get "/excerpts/add" (fun _req -> respond' @@ Content.add_excerpt_page)

let respond_or_err resp = function
  | Ok v -> respond' @@ resp v
  | Error err -> respond' @@ Content.error_page err

let excerpt_of_form_data data =
  let find data key =
    let open Core in
    (* NOTE Should handle error in case of missing fields *)
    List.Assoc.find_exn ~equal:String.equal data key |> String.concat
  in
  let author = find data "author"
  and excerpt = find data "excerpt"
  and source = find data "source"
  and page = match find data "page" with "" -> None | p -> Some p in
  Lwt.return Excerpt.{ author; excerpt; source; page }

(* let post_excerpts_add = post "/excerpts/add" begin fun req ->
 *     let open Lwt in
 *     (\* NOTE Should handle possible error arising from invalid data *\)
 *     App.urlencoded_pairs_of_body req  >>=
 *     excerpt_of_form_data              >>= fun excerpt ->
 *     Db.Update.add_excerpt excerpt req >>=
 *     respond_or_err (fun () -> Content.excerpt_added_page excerpt)
 *   end
 *
 * let excerpts_by_author = get "/excerpts/author/:name" begin fun req ->
 *     let open Lwt in
 *     Db.Get.excerpts_by_author (param req "name") req >>=
 *     respond_or_err Content.excerpts_listing_page
 *   end
 *
 * let excerpts = get "/excerpts" begin fun req ->
 *     let open Lwt in
 *     Db.Get.authors req >>=
 *     respond_or_err Content.author_excerpts_page
 *   end *)

let routes = [ root; hello; hello_fallback; get_excerpts_add ]

let add_routes app =
  Core.List.fold ~f:(fun app route -> route app) ~init:app routes
