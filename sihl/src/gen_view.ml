let template =
  {|
open Tyxml

type t = {{module}}.t

let skip_index_fetch = false

(* General *)

let%html alert_message alert =
  {|<span class="alert">\|\}
    [ Html.txt (Option.value alert ~default:"") ]
    {|</span>\|\}
;;

let%html notice_message notice =
  {|<span class="notice">\|\}
    [ Html.txt (Option.value notice ~default:"") ]
    {|</span>\|\}
;;

let%html page alert notice body =
  {|
<!doctype html>
<html lang="en">
  <head>
    <meta charset="UTF-8"/>
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>{{module}}</title>
    <link rel="stylesheet" href="https://fonts.xz.style/serve/inter.css">
    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/@exampledev/new.css@1.1.2/new.min.css">
    {{style}}
    <style>
      .alert {
        color: red;
      }
      .notice {
        color: green;
      }
    </style>
  </head>
    <body>\|\}
    [ alert_message alert ]
    [ notice_message notice ]
    body
    {|
    {{scripts}}
  </body>
</html>
\|\}
;;

let%html delete_button ({{name}} : {{module}}.t) (query : Sihl.Web.Rest.query) csrf =
  {|
<form action="\|\}
    (Format.sprintf
      "/{{name}}s/%s%s"
      {{name}}.{{module}}.id
      (Sihl.Web.Rest.to_query_string query))
    {|" method="Post">
  <input type="hidden" name="_csrf" value="\|\}
    csrf
    {|">
  <input type="hidden" name="_method" value="delete">
  <input type="submit" value="Delete">
</form>
\|\}
;;

let%html create_link = {|<div><a href="/{{name}}s/new">Create</a></div>\|\}

let%html edit_link name =
  {|<a href="\|\} (Format.sprintf "/{{name}}s/%s/edit" name) {|">Edit</a>\|\}
;;

let form_comp form ({{name}} : {{module}}.t option) =
  {{form_values}}
  {{default_values}}
  [%html {| {{form}} \|\}]
;;

(* Index *)

let%html table_header = {|<tr style="white-space: nowrap;">
  <th>Id</th>
  {{table_header}}
  <th>Created at</th>
  <th>Updated at</th>
  <th>Actions</th>
</tr>\|\}
;;

let%html table_row csrf query ({{name}} : {{module}}.t) =
  {|<tr><td><a href="\|\}
    (Format.sprintf "/{{name}}s/%s" {{name}}.{{module}}.id)
    {|">\|\}
    [ Html.txt {{name}}.{{module}}.id ]
    {|</a></td>\|\}
    {{table_rows}}
    {|<td>\|\}
    [ Html.txt (Ptime.to_rfc3339 {{name}}.{{module}}.created_at) ]
    {|</td><td>\|\}
    [ Html.txt (Ptime.to_rfc3339 {{name}}.{{module}}.updated_at) ]
    {|</td><td>\|\}
    [ delete_button {{name}} query csrf ]
    [ edit_link {{name}}.{{module}}.id ]
    {|</td></tr>\|\}
;;

let%html table table_header items =
  {|<div><h3>{{module}}s</h3><table><tbody>\|\}
    (List.cons table_header items)
    {|</tbody></table></div>\|\}
;;

let%html search_box (query : Sihl.Web.Rest.query) =
  {|
<form action="/{{name}}s" method="Get">
  <input type="text" name="filter" value="\|\}
    (Option.value ~default:"" (Sihl.Web.Rest.query_filter query))
    {|">
  <input type="hidden" name="sort" value="\|\}
    (Option.value ~default:"" (Sihl.Web.Rest.query_sort query))
    {|">
  <input type="hidden" name="limit" value="\|\}
    (Option.value ~default:"" (Sihl.Web.Rest.query_limit query))
    {|">
  <input type="hidden" name="offset" value="\|\}
    (Option.value ~default:"" (Sihl.Web.Rest.query_offset query))
    {|">
  <input type="submit" value="Search">
</form>
\|\}
;;

let navigate_page label (query : Sihl.Web.Rest.query option) =
  match query with
  | Some query ->
    [ [%html
        {|
<form style="display: inline;" action="/{{name}}s" method="Get">
  <input type="hidden" name="filter" value="\|\}
          (Option.value ~default:"" (Sihl.Web.Rest.query_filter query))
          {|">
  <input type="hidden" name="sort" value="\|\}
          (Option.value ~default:"" (Sihl.Web.Rest.query_sort query))
          {|">
  <input type="hidden" name="limit" value="\|\}
          (Option.value ~default:"" (Sihl.Web.Rest.query_limit query))
          {|">
  <input type="hidden" name="offset" value="\|\}
          (Option.value ~default:"" (Sihl.Web.Rest.query_offset query))
          {|">
  <input type="submit" value="\|\}
          label
          {|">
</form>
     \|\}]
    ]
  | None ->
    [ [%html
        {|
<form style="display: inline;" action="/{{name}}s" method="Get">
  <input type="submit" value="\|\}
          label
          {|" disabled>
</form>
\|\}]
    ]
;;

let%html pagination (query : Sihl.Web.Rest.query) (total : int) =
  "<div>"
    (navigate_page "First" (Sihl.Web.Rest.first_page query))
    (navigate_page "Previous" (Sihl.Web.Rest.previous_page query))
    (navigate_page "Next" (Sihl.Web.Rest.next_page query total))
    (navigate_page "Last" (Sihl.Web.Rest.last_page query total))
    "</div>"
;;

let limit_option (limit : int option) (to_show : int) =
  if Option.equal Int.equal limit (Some to_show)
  then
    [ [%html
        "<option selected value="
          (string_of_int to_show)
          ">"
          (Html.txt (string_of_int to_show))
          "</option>"]
    ]
  else
    [ [%html
        "<option value="
          (string_of_int to_show)
          ">"
          (Html.txt (string_of_int to_show))
          "</option>"]
    ]
;;

let%html total_items (total : int) =
  {|<span>\|\} [ Html.txt (Format.sprintf "Total: %d" total) ] {|</span>\|\}
;;

let%html page_size (query : Sihl.Web.Rest.query) =
  {|
<form action="/{{name}}s" method="Get">
  <input type="hidden" name="filter" value="\|\}
    (query |> Sihl.Web.Rest.query_filter |> Option.value ~default:"")
    {|">
  <input type="hidden" name="sort" value="\|\}
    (Option.value ~default:"" (Sihl.Web.Rest.query_sort query))
    {|">
  <label>Results per page:</label>
  <select name="limit"> \|\}
    (limit_option query.Sihl.Web.Rest.limit 25)
    (limit_option query.Sihl.Web.Rest.limit 50)
    (limit_option query.Sihl.Web.Rest.limit 100)
    (limit_option query.Sihl.Web.Rest.limit 500)
    {|
  </select>
  <input type="hidden" name="offset" value="\|\}
    (Option.value ~default:"" (Sihl.Web.Rest.query_offset query))
    {|">
  <input type="submit" value="Set">
</form>
\|\}
;;

(* Views *)

let index req csrf (result : {{module}}.t list * int) query =
  let {{name}}s, total = result in
  let notice = Sihl.Web.Flash.find_notice req in
  let alert = Sihl.Web.Flash.find_alert req in
  let items = List.map(table_row csrf query) {{name}}s in
  let table = table table_header items in
  Lwt.return
  @@ page
       alert
       notice
       [ search_box query
       ; create_link
       ; table
       ; total_items total
       ; page_size query
       ; pagination query total
       ]
;;

let new' req csrf (form : Sihl.Web.Rest.form) =
  let notice = Sihl.Web.Flash.find_notice req in
  let alert = Sihl.Web.Flash.find_alert req in
  let form =
    [%html
      {|
<form action="/{{name}}s" method="Post">
  <input type="hidden" name="_csrf" value="\|\}
        csrf
        {|">
         \|\}
        (form_comp form None)
        {|
  <div>
    <input type="submit" value="Create">
  </div>
</form>
\|\}]
  in
  Lwt.return @@ page alert notice [ form ]
;;

let show req ({{name}} : {{module}}.t) =
  let notice = Sihl.Web.Flash.find_notice req in
  let alert = Sihl.Web.Flash.find_alert req in
  let body = [%html {{show}}] in
  Lwt.return @@ page alert notice [ body ]
;;

let edit req csrf (form : Sihl.Web.Rest.form) ({{name}} : {{module}}.t) =
  let notice = Sihl.Web.Flash.find_notice req in
  let alert = Sihl.Web.Flash.find_alert req in
  let form =
    [%html
      {|
<form action="\|\}
        (Format.sprintf "/{{name}}s/%s" {{name}}.{{module}}.id)
        {|" method="Post">
  <input type="hidden" name="_csrf" value="\|\}
        csrf
        {|">
  <input type="hidden" name="_method" value="put">\|\}
        (form_comp form (Some {{name}}))
        {|<input type="submit" value="Update">
</form>
\|\}]
  in
  Lwt.return @@ page alert notice [ form ]
;;
|}
;;

let dune_template =
  {|(library
 (name view_{{name}})
 (libraries tyxml sihl service {{name}})
 (preprocess
  (pps tyxml-ppx)))
|}
;;

let unescape_template (t : string) : string =
  t |> CCString.replace ~sub:{|\|\}|} ~by:"|}"
;;

let table_header (schema : Gen_core.schema) : string =
  schema
  |> List.map fst
  |> List.map String.capitalize_ascii
  |> List.map (Format.sprintf "<th>%s</th>")
  |> String.concat "\n"
;;

let stringify name module_name (field_name, type_) =
  let open Gen_core in
  match type_ with
  | Float ->
    Format.sprintf
      "[ Html.txt (string_of_float %s.%s.%s) ]"
      name
      module_name
      field_name
  | Int ->
    Format.sprintf
      "[ Html.txt (string_of_int %s.%s.%s) ]"
      name
      module_name
      field_name
  | Bool ->
    Format.sprintf
      "[ Html.txt (string_of_bool %s.%s.%s) ]"
      name
      module_name
      field_name
  | String -> Format.sprintf "[ Html.txt %s.%s.%s ]" name module_name field_name
  | Datetime ->
    Format.sprintf
      "[ Html.txt (Ptime.to_rfc3339 %s.%s.%s) ]"
      name
      module_name
      field_name
;;

let table_rows name module_name (schema : Gen_core.schema) =
  schema
  |> List.map (fun field ->
         Format.sprintf "\"<td>\"%s\"</td>\"" (stringify name module_name field))
  |> String.concat "\n"
;;

let form_values schema =
  schema
  |> List.map fst
  |> List.map (fun name ->
         Format.sprintf
           "let old_%s, %s_error = Sihl.Web.Rest.find_form \"%s\" form in"
           name
           name
           name)
  |> String.concat "\n"
;;

let default_value type_ =
  let open Gen_core in
  match type_ with
  | Float -> "0.0"
  | Int -> "0"
  | Bool -> "false"
  | String -> "\"\""
  | Datetime -> "(Ptime_clock.now ())"
;;

let checkbox field_name field_type =
  let open Gen_core in
  match field_type with
  | Bool ->
    Format.sprintf
      {|
  let %s =
    if current_%s || Option.equal String.equal old_%s (Some "true")
    then [|}
      field_name
      field_name
      field_name
    ^ "%h"
    ^ Format.sprintf
        {|tml {|<input type="checkbox" name="%s" value="true" checked>\|\}]
    else [|}
        field_name
    ^ "%h"
    ^ Format.sprintf
        {|tml {|<input type="checkbox" name="%s" value="true">\|\}]
  in
|}
        field_name
    |> unescape_template
  | Float | Int | String | Datetime -> ""
;;

let default_values name module_name schema =
  schema
  |> List.map (fun (field_name, field_type) ->
         Format.sprintf
           {|
  let current_%s =
    %s
    |> Option.map (fun (%s : %s.t) -> %s.%s.%s)
    |> Option.value ~default:%s
  in
  %s
|}
           field_name
           name
           name
           module_name
           name
           module_name
           field_name
           (default_value field_type)
           (checkbox field_name field_type))
  |> String.concat "\n"
;;

let form_input (field_name, field_type) =
  let open Gen_core in
  match field_type with
  | Float ->
    Format.sprintf
      {|<input name="%s" value="\|\}
        (Option.value ~default:current_%s old_%s)
        {|">|}
      field_name
      field_name
      field_name
  | Int ->
    Format.sprintf
      {|<input name="%s" value="\|\}
        (Option.value ~default:(string_of_int current_%s) old_%s)
        {|">|}
      field_name
      field_name
      field_name
  | Bool ->
    Format.sprintf
      {|\|\} [ %s ] {|
<input type="hidden" name="%s" value="false">
|}
      field_name
      field_name
    |> unescape_template
  | String ->
    Format.sprintf
      {|<input name="%s" value="\|\}
        (Option.value ~default:current_%s old_%s)
        {|">|}
      field_name
      field_name
      field_name
  | Datetime ->
    Format.sprintf
      {|<input class="datetime" type="datetime-local" name="%s" value="\|\}
    (* Not that datetime-local is not yet supported by many browsers. You might
       want to use some datepicker library *)
        (Option.value ~default:(Ptime.to_rfc3339 current_%s) old_%s)
        {|">|}
      field_name
      field_name
      field_name
;;

let alert (field_name, _) =
  Format.sprintf
    {|<p class="alert">\|\}
      [ Html.txt (Option.value ~default:"" %s_error) ]
  {|</p>|}
    field_name
;;

let form_elements schema =
  schema
  |> List.map (fun field ->
         Format.sprintf
           {|
    <div>
      <label>%s</label>
      %s
    </div>
    %s
|}
           (String.capitalize_ascii (fst field))
           (form_input field)
           (alert field))
  |> String.concat "\n"
  |> unescape_template
;;

let show name module_name (schema : Gen_core.schema) =
  schema
  |> List.map (fun field ->
         Format.sprintf
           {|"<div><span>%s: </span><span>" %s "</span></div>"|}
           name
           (stringify name module_name field))
  |> String.concat "\n"
  |> fun fields ->
  Format.sprintf
    "\"<div>\"%s [ edit_link %s.%s.id ]\"</div>\""
    fields
    name
    module_name
;;

let has_datetime schema =
  let open Gen_core in
  schema
  |> List.map snd
  |> List.find_opt (function
         | Datetime -> true
         | Int | Float | String | Bool -> false)
  |> Option.map (fun _ -> true)
  |> Option.value ~default:false
;;

let scripts (schema : Gen_core.schema) =
  if has_datetime schema
  then
    {|<script src="https://cdnjs.cloudflare.com/ajax/libs/jquery/3.6.0/jquery.min.js" integrity="sha512-894YE6QWD5I59HgZOGReFYm4dnWc1Qt5NtvYSaNcOP+u1T9qYdvdihz0PPSiiqn/+/3e7Jo4EaG7TubfWGUrMQ==" crossorigin="anonymous"></script>
    <script src="https://cdn.jsdelivr.net/npm/flatpickr"></script>
    <script>\|\}
    (Tyxml.Html.Unsafe.data
       {|(function() { $( ".datetime" ).flatpickr({enableTime:true, dateFormat:"Z"}); })();\|\})
   {|</script>|}
    |> unescape_template
  else ""
;;

let style (schema : Gen_core.schema) =
  if has_datetime schema
  then
    {|<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/flatpickr/dist/flatpickr.min.css">|}
  else ""
;;

let create_params name (schema : Gen_core.schema) =
  let module_name = CCString.capitalize_ascii name in
  [ "module", module_name
  ; "name", name
  ; "table_header", table_header schema
  ; "table_rows", table_rows name module_name schema
  ; "form_values", form_values schema
  ; "default_values", default_values name module_name schema
  ; "form", form_elements schema
  ; "show", show name module_name schema
  ; "scripts", scripts schema
  ; "style", style schema
  ]
;;

let generate (name : string) (schema : Gen_core.schema) =
  if String.contains name ':'
  then failwith "Invalid service name provided, it can not contain ':'"
  else (
    let dune_file =
      Gen_core.
        { name = "dune"; template = dune_template; params = [ "name", name ] }
    in
    let file =
      Gen_core.
        { name = Format.sprintf "view_%s.ml" name
        ; template = unescape_template template
        ; params = create_params name schema
        }
    in
    Gen_core.write_in_view name [ dune_file; file ])
;;
