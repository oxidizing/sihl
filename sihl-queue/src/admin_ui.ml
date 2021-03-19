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
  <button type="submit" style="transition:none; font-size:12px;">Cancel</button>
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
  <button type="submit" style="transition:none; font-size:12px;">Re-queue</button>
</form>
|}]
;;

let status scope csrf (job : Sihl.Contract.Queue.instance) =
  let now = Ptime_clock.now () in
  match job.status with
  | Sihl.Contract.Queue.Succeeded ->
    [%html
      {|<div><span>Succeeded</span>|} [ requeue scope csrf job.id ] {|</div>|}]
  | Sihl.Contract.Queue.Failed ->
    [%html
      {|<div><span style="color:#a10d0d;;">Failed</span>|}
        [ requeue scope csrf job.id ]
        {|</div>|}]
  | Sihl.Contract.Queue.Cancelled ->
    [%html
      {|<div><span style="color:#a10d0d;;">Cancelled</span>|}
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
      {|<div><span>|}
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

let row scope csrf (job : Sihl.Contract.Queue.instance) =
  let last_error_at =
    job.last_error_at
    |> Option.map Ptime.to_rfc3339
    |> Option.value ~default:"Never"
  in
  let input =
    if String.equal job.input ""
    then [%html {|<td>|} [ Html.txt "" ] {| </td>|}]
    else
      [%html
        {|<td><pre style="|}
          pre_style
          {|">|}
          [ Html.txt job.input ]
          {|</pre></td>|}]
  in
  [%html
    {|
<tr>
      <td>|}
      [ Html.txt job.id ]
      {|</td>
      <td>|}
      [ Html.txt job.name ]
      {|</td>|}
      [ input ]
      {|<td>|}
      [ Html.txt (Format.sprintf "%d/%d" job.tries job.max_tries) ]
      {|</td>
      <td><pre style="|}
      pre_style
      {|">|}
      [ Html.txt (Option.value ~default:"" job.last_error) ]
      {|</pre>
      </td>
      <td>|}
      [ Html.txt last_error_at ]
      {|
      </td>
      <td>|}
      [ status scope csrf job ]
      {|</td>
</tr>
|}]
;;

let table scope csrf (jobs : Sihl.Contract.Queue.instance list) =
  let path = Format.sprintf "%s/html/index" scope in
  [%html
    {|
<table data-hx-get="|}
      path
      {|" data-hx-trigger="every 5s" data-hx-swap="outerHTML">
  <thead>
    <tr>
      <th>ID</th>
      <th>Job type</th>
      <th>Input</th>
      <th>Tries</th>
      <th>Last error</th>
      <th>Last error at</th>
      <th>Status</th>
    </tr>
  </thead>
   <tbody>
   |}
      (List.map (row scope csrf) jobs)
      {|
   </tbody>
</table>
|}]
;;

let page ?back body =
  let body =
    match back with
    | Some back ->
      let back_button = [%html {|<a href="|} back {|">← Go back</a>|}] in
      List.cons back_button body
    | None -> body
  in
  let body =
    match Sihl.Configuration.read_string "HTMX_SCRIPT_URL" with
    | Some htmx ->
      let htmx_script = [%html {|<script src="|} htmx {|"></script>|}] in
      List.concat [ body; [ htmx_script ] ]
    | None -> body
  in
  [%html
    {|
<!doctype html>
<html lang="en">
  <head>
    <meta charset="UTF-8"/>
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <link href="/assets/styles.css" rel="stylesheet">
    <title>Hello world!</title>
  </head>
    <body>|}
      body
      {|
     </body>
</html>
|}]
;;

let index ?back scope find_jobs =
  let open Lwt.Syntax in
  Sihl.Web.get "" (fun req ->
      let csrf = Sihl.Web.Csrf.find req |> Option.get in
      let* jobs = find_jobs () in
      Lwt.return
      @@ Sihl.Web.Response.of_html (page ?back [ table scope csrf jobs ]))
;;

let html_index scope find_jobs =
  let open Lwt.Syntax in
  Sihl.Web.get "/html/index" (fun req ->
      let csrf = Sihl.Web.Csrf.find req |> Option.get in
      let* jobs = find_jobs () in
      let html =
        Format.asprintf "%a" Tyxml.Html._pp_elt (table scope csrf jobs)
      in
      Lwt.return @@ Sihl.Web.Response.of_plain_text html)
;;

let cancel scope find_job cancel_job =
  let open Lwt.Syntax in
  Sihl.Web.post "/:id/cancel" (fun req ->
      let id = Sihl.Web.Router.param req "id" in
      let* job = find_job id in
      let* _ = cancel_job job in
      Lwt.return @@ Sihl.Web.Response.redirect_to scope)
;;

let requeue scope find_job requeue_job =
  let open Lwt.Syntax in
  Sihl.Web.post "/:id/requeue" (fun req ->
      let id = Sihl.Web.Router.param req "id" in
      let* job = find_job id in
      let* _ = requeue_job job in
      Lwt.return @@ Sihl.Web.Response.redirect_to scope)
;;

let middlewares =
  [ Opium.Middleware.content_length
  ; Opium.Middleware.etag
  ; Sihl.Web.Middleware.csrf ()
  ; Sihl.Web.Middleware.flash ()
  ]
;;

let router search_jobs find_job cancel_job requeue_job ?back scope =
  Sihl.Web.choose
    ~middlewares
    ~scope
    [ index ?back scope search_jobs
    ; html_index scope search_jobs
    ; cancel scope find_job cancel_job
    ; requeue scope find_job requeue_job
    ]
;;
