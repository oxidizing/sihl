open Tyxml

let cancel scope csrf id =
  let path = Format.sprintf "%s/%s/cancel" scope id in
  [%html
    {|
<form style="display: inline;" action="|}
      path
      {|" method="Post">
  <input type="hidden" name="csrf" value="|}
      csrf
      {|">
  <input type="hidden" id="|}
      id
      {|">
  <button type="submit" class="sihl-admin-ui-table-row-cancel sihl-admin-ui-queue-table-row-cancel sihl-admin-ui-queue-table-button">Cancel</button>
</form>
|}]
;;

let requeue scope csrf id =
  let path = Format.sprintf "%s/%s/requeue" scope id in
  [%html
    {|
<form style="display: inline;" action="|}
      path
      {|" method="Post">
  <input type="hidden" name="csrf" value="|}
      csrf
      {|">
  <input type="hidden" id="|}
      id
      {|">
  <button type="submit" class="sihl-admin-ui-table-row-requeue sihl-admin-ui-queue-table-row-requeue sihl-admin-ui-queue-table-button">Re-queue</button>
</form>
|}]
;;

let status ?prefix scope csrf (job : Sihl.Contract.Queue.instance) =
  let scope = Format.asprintf "%s%s" scope (Option.value ~default:"" prefix) in
  let now = Ptime_clock.now () in
  match job.status with
  | Sihl.Contract.Queue.Succeeded ->
    [%html
      {|<div><span class="sihl-admin-ui-table-row-success sihl-admin-ui-queue-table-row-success">Succeeded</span>|}
        [ requeue scope csrf job.id ]
        {|</div>|}]
  | Sihl.Contract.Queue.Failed ->
    [%html
      {|<div><span class="sihl-admin-ui-table-row-failed sihl-admin-ui-queue-table-row-failed">Failed</span>|}
        [ requeue scope csrf job.id ]
        {|</div>|}]
  | Sihl.Contract.Queue.Cancelled ->
    [%html
      {|<div><span class="sihl-admin-ui-table-row-failed sihl-admin-ui-queue-table-row-failed">Cancelled</span>|}
        [ requeue scope csrf job.id ]
        {|</div>|}]
  | Sihl.Contract.Queue.Pending ->
    let next_try_in =
      if Ptime.is_earlier now ~than:job.next_run_at
      then
        Some
          (Ptime.Span.round
             ~frac_s:0
             (Ptime.Span.sub
                (Ptime.to_span job.next_run_at)
                (Ptime.to_span now)))
      else None
    in
    let next_try_in =
      next_try_in
      |> Option.map (Format.asprintf "%a" Ptime.Span.pp)
      |> Option.value ~default:"0s"
      |> Format.sprintf "Next try in: %s"
    in
    [%html
      {|<div><span class="sihl-admin-ui-table-row-pending sihl-admin-ui-queue-table-row-pending">|}
        [ Html.txt next_try_in ]
        {|</span>|}
        [ cancel scope csrf job.id ]
        {|</div>|}]
;;

let pre_style =
  {|
    white-space: pre-wrap;
    white-space: -moz-pre-wrap;
    white-space: -pre-wrap;
    white-space: -o-pre-wrap;
    word-wrap: break-word;
|}
;;

let row ?prefix scope csrf (job : Sihl.Contract.Queue.instance) =
  let last_error_at =
    job.last_error_at
    |> Option.map Ptime.to_rfc3339
    |> Option.value ~default:"Never"
  in
  let status_class =
    match job.status with
    | Sihl.Contract.Queue.Succeeded -> "succeeded"
    | Sihl.Contract.Queue.Failed -> "failed"
    | Sihl.Contract.Queue.Cancelled -> "cancelled"
    | Sihl.Contract.Queue.Pending -> "pending"
  in
  let classes =
    [ "sihl-admin-ui-table-body-row"
    ; "sihl-admin-ui-queue-table-body-row"
    ; Format.asprintf
        "sihl-admin-ui-queue-table-body-row-status-%s"
        status_class
    ]
  in
  let input =
    if String.equal job.input ""
    then
      [%html
        {|<td class="sihl-admin-ui-table-body-cell sihl-admin-ui-queue-table-body-cell">|}
          [ Html.txt "" ]
          {| </td>|}]
    else
      [%html
        {|<td class="sihl-admin-ui-table-body-cell sihl-admin-ui-queue-table-body-cell"><pre style="|}
          pre_style
          {|">|}
          [ Html.txt job.input ]
          {|</pre></td>|}]
  in
  [%html
    {|
<tr class="|}
      classes
      {|">
      <td class="sihl-admin-ui-table-body-cell sihl-admin-ui-queue-table-body-cell">|}
      [ Html.txt job.id ]
      {|</td>
      <td class="sihl-admin-ui-table-body-cell sihl-admin-ui-queue-table-body-cell">|}
      [ Html.txt job.name ]
      {|</td>|}
      [ input ]
      {|<td class="sihl-admin-ui-table-body-cell sihl-admin-ui-queue-table-body-cell">|}
      [ Html.txt (Format.sprintf "%d/%d" job.tries job.max_tries) ]
      {|</td>
      <td class="sihl-admin-ui-table-body-cell sihl-admin-ui-queue-table-body-cell"><pre style="|}
      pre_style
      {|">|}
      [ Html.txt (Option.value ~default:"" job.last_error) ]
      {|</pre>
      </td>
      <td class="sihl-admin-ui-table-body-cell sihl-admin-ui-queue-table-body-cell">|}
      [ Html.txt last_error_at ]
      {|
      </td>
      <td class="sihl-admin-ui-table-body-cell sihl-admin-ui-queue-table-body-cell">|}
      [ status ?prefix scope csrf job ]
      {|</td>
</tr>
|}]
;;

let table ?prefix scope csrf (jobs : Sihl.Contract.Queue.instance list) =
  let path = Format.sprintf "%s/html/index" scope in
  [%html
    {|
<table data-hx-get="|}
      path
      {|" data-hx-trigger="every 5s" data-hx-swap="outerHTML" class="sihl-admin-ui-table sihl-admin-ui-queue-table">
  <thead class="sihl-admin-ui-table-header sihl-admin-ui-queue-table-header">
    <tr class="sihl-admin-ui-table-header-row sihl-admin-ui-queue-table-header-row">
      <th class="sihl-admin-ui-table-header-cell sihl-admin-ui-queue-table-header-cell">ID</th>
      <th class="sihl-admin-ui-table-header-cell sihl-admin-ui-queue-table-header-cell">Job type</th>
      <th class="sihl-admin-ui-table-header-cell sihl-admin-ui-queue-table-header-cell">Input</th>
      <th class="sihl-admin-ui-table-header-cell sihl-admin-ui-queue-table-header-cell">Tries</th>
      <th class="sihl-admin-ui-table-header-cell sihl-admin-ui-queue-table-header-cell">Last error</th>
      <th class="sihl-admin-ui-table-header-cell sihl-admin-ui-queue-table-header-cell">Last error at</th>
      <th class="sihl-admin-ui-table-header-cell sihl-admin-ui-queue-table-header-cell">Status</th>
    </tr>
  </thead>
   <tbody class="sihl-admin-ui-table-body sihl-admin-ui-queue-table-body">
   |}
      (List.map (row ?prefix scope csrf) jobs)
      {|
   </tbody>
</table>
|}]
;;

let base =
  [%html
    {|
body {
    font-family: sans-serif;
}
.sihl-admin-ui-queue-back {
    text-decoration: none;
    font-size: 1.5rem;
}

.sihl-admin-ui-table {
    width: 100%;
    border-collapse: collapse;
    margin-top: 10px;
}

.sihl-admin-ui-table-header-cell, .sihl-admin-ui-table-body-cell {
    text-align: left;
    padding: 12px 15px;
}

.sihl-admin-ui-queue-table-button {
    cursor: pointer;
    margin-top: 5px;
    padding: 5px 10px;
    border-radius: 0.2em;
    text-decoration: none;
    text-align: center;
    -webkit-transition: all 0.2s;
    -o-transition: all 0.2s;
    transition: all 0.2s;
}
|}]
;;

let light =
  [%html
    {|
.sihl-admin-ui-table-header-cell, .sihl-admin-ui-table-body-cell {
    border: 1px solid black;
}

.sihl-admin-ui-queue-table-header {
    background-color: #DDDDDD;
}

.sihl-admin-ui-queue-table-body-row-status-failed {
    background-color: #FFCCCC;
}

.sihl-admin-ui-queue-table-body-row-status-succeeded {
    background-color: #CCFFCC;
}

.sihl-admin-ui-queue-table-button {
    border: 1px solid black;
}
.sihl-admin-ui-queue-table-button:hover{
    color: #FFFFFF;
    background-color: #777777;
}
|}]
;;

let dark =
  [%html
    {|
body {
    background-color: #282828;
}

.sihl-admin-ui-queue-back {
    color: white;
}

.sihl-admin-ui-table-header-cell, .sihl-admin-ui-table-body-cell {
    border: 1px solid #282828;
    color: #D8D8D8;
}

.sihl-admin-ui-queue-table-header {
    background-color: #404040;
}

.sihl-admin-ui-queue-table-body-row-status-failed {
    background-color: #5d3030;
}

.sihl-admin-ui-queue-table-body-row-status-succeeded {
    background-color: #305430;
}

.sihl-admin-ui-queue-table-button {
    border: 1px solid #282828;
    background-color: #282828;
    color: white;
}
.sihl-admin-ui-queue-table-button:hover{
    color: black;
    background-color: #EEEEEE;
}
|}]
;;

let page ?back ?theme body =
  let body =
    match back with
    | Some back ->
      let back_button =
        [%html
          {|<a href="|}
            back
            {|" class="sihl-admin-ui-back sihl-admin-ui-queue-back">← Go back</a>|}]
      in
      List.cons back_button body
    | None -> body
  in
  let body =
    match theme with
    | Some `Light ->
      let theme = [%html {|<style>|} [ base; light ] {|</style>|}] in
      List.concat [ body; [ theme ] ]
    | Some `Dark ->
      let theme = [%html {|<style>|} [ base; dark ] {|</style>|}] in
      List.concat [ body; [ theme ] ]
    | Some (`Custom _) -> body
    | None ->
      let theme = [%html {|<style>|} [ base; light ] {|</style>|}] in
      List.concat [ body; [ theme ] ]
  in
  let body =
    match Sihl.Configuration.read_string "HTMX_SCRIPT_URL" with
    | Some htmx ->
      let htmx_script = [%html {|<script src="|} htmx {|"></script>|}] in
      List.concat [ body; [ htmx_script ] ]
    | None -> body
  in
  match theme with
  | Some (`Custom url) ->
    [%html
      {|
       <!doctype html>
       <html lang="en">
         <head>
           <meta charset="UTF-8"/>
           <meta name="viewport" content="width=device-width, initial-scale=1">
           <link href="|}
        url
        {|" rel="stylesheet">
           <title>Queue Dashboard</title>
         </head>
           <body>|}
        body
        {|
           </body>
       </html>
      |}]
  | _ ->
    [%html
      {|
       <!doctype html>
       <html lang="en">
         <head>
           <meta charset="UTF-8"/>
           <meta name="viewport" content="width=device-width, initial-scale=1">
           <title>Queue Dashboard</title>
         </head>
           <body>|}
        body
        {|
           </body>
       </html>
      |}]
;;

let index ?prefix ?back ?theme scope find_jobs =
  Sihl.Web.get "" (fun req ->
    let csrf =
      match Sihl.Web.Csrf.find req with
      | Some csrf -> csrf
      | None -> failwith "No CSRF token found"
    in
    let%lwt jobs = find_jobs () in
    Lwt.return
    @@ Sihl.Web.Response.of_html
         (page ?back ?theme [ table ?prefix scope csrf jobs ]))
;;

let html_index scope find_jobs =
  Sihl.Web.get "/html/index" (fun req ->
    let csrf =
      match Sihl.Web.Csrf.find req with
      | Some csrf -> csrf
      | None -> failwith "No CSRF token found"
    in
    let%lwt jobs = find_jobs () in
    let html =
      Format.asprintf "%a" Tyxml.Html._pp_elt (table scope csrf jobs)
    in
    Lwt.return @@ Sihl.Web.Response.of_plain_text html)
;;

let cancel scope find_job cancel_job =
  Sihl.Web.post "/:id/cancel" (fun req ->
    let id = Sihl.Web.Router.param req "id" in
    let%lwt job = find_job id in
    let%lwt _ = cancel_job job in
    Lwt.return @@ Sihl.Web.Response.redirect_to scope)
;;

let requeue scope find_job requeue_job =
  Sihl.Web.post "/:id/requeue" (fun req ->
    let id = Sihl.Web.Router.param req "id" in
    let%lwt job = find_job id in
    let%lwt _ = requeue_job job in
    Lwt.return @@ Sihl.Web.Response.redirect_to scope)
;;

let middlewares =
  [ Opium.Middleware.content_length
  ; Opium.Middleware.etag
  ; Sihl.Web.Middleware.csrf ()
  ; Sihl.Web.Middleware.flash ()
  ]
;;

let router
      search_jobs
      find_job
      cancel_job
      requeue_job
      ?back
      ?theme
      ?prefix
      scope
  =
  Sihl.Web.choose
    ~middlewares
    ~scope
    [ index ?prefix ?back ?theme scope search_jobs
    ; html_index scope search_jobs
    ; cancel scope find_job cancel_job
    ; requeue scope find_job requeue_job
    ]
;;
