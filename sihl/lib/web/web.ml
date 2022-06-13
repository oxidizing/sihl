let reverse ?(params : (string * string) list = []) (url : string) =
  params |> ignore;
  url |> ignore;
  failwith "reverse()"
;;

module Form = struct
  type widget = TextArea
  type input_field = Model.any_field * widget option
  type 'a t = ('a, input_field) Model.record
  type 'a valid
  type 'a invalid

  type generic =
    { name : string
    ; fields : input_field list
    }

  let generic (t : 'a t) : generic = { name = t.name; fields = t.fields }

  let int
      ?widget
      ?default
      ?nullable
      (record_field : ('perm, 'record, int) Model.record_field)
      : input_field
    =
    Model.int ?default ?nullable record_field, widget
  ;;

  let timestamp
      ?widget
      ?default
      ?nullable
      ?update
      (record_field : ('perm, 'record, Ptime.t) Model.record_field)
      : input_field
    =
    Model.timestamp ?default ?nullable ?update record_field, widget
  ;;

  let string
      ?widget
      ?default
      ?nullable
      (record_field : ('perm, 'record, string) Model.record_field)
      : input_field
    =
    Model.string ?default ?nullable record_field, widget
  ;;

  let validate_form (form : 'a t) : 'a t =
    let schema_field_names =
      List.map (fun (field, _) -> Model.field_name field) form.fields
    in
    let field_names = form.field_names in
    if CCList.equal
         String.equal
         (CCList.sort compare schema_field_names)
         (CCList.sort compare field_names)
    then form
    else
      failwith
      @@ Format.sprintf
           "you did not list all fields of the form '%s' in the schema, make \
            sure to list all the fields to the record type"
           form.name
  ;;

  let forms : (string, generic) Hashtbl.t = Hashtbl.create 100

  let create
      ?(validate = fun _ -> [])
      to_yojson
      of_yojson
      (name : string)
      (field_names : string list)
      (fields : input_field list)
    =
    let form : 'a t =
      { name; fields; field_names; to_yojson; of_yojson; validate }
    in
    let form : 'a t = form |> validate_form in
    if Hashtbl.mem forms name
    then
      failwith
      @@ Format.sprintf
           "a form named %s was already defined, make sure that you don't use \
            the same name twice"
           name
    else Hashtbl.add forms name (generic form);
    form
  ;;

  let of_model
      ?(widgets : (('perm, 'record, string) Model.record_field * widget) list =
        [])
      (model : 'a Model.t)
    =
    let _, record = model in
    let input_fields : input_field list =
      record.fields
      |> List.map (fun (Model.AnyField (name, _) as any_field) ->
             ( any_field
             , List.find_opt
                 (fun (record_field, _) ->
                   String.equal (Fieldslib.Field.name record_field) name)
                 widgets
               |> Option.map snd ))
    in
    let form : 'a t =
      { name = record.name ^ "_form"
      ; fields = input_fields
      ; field_names = record.field_names
      ; to_yojson = record.to_yojson
      ; of_yojson = record.of_yojson
      ; validate = record.validate
      }
    in
    widgets |> ignore;
    form
  ;;
end

module View = struct
  let form
      (type a b)
      ~(success_url : Dream.request -> string Lwt.t)
      ~(on_valid : Dream.request -> a Form.valid -> b Lwt.t)
      ~(on_invalid : Dream.request -> a Form.invalid -> b Lwt.t)
      (form : a Form.t)
      (template : Dream.request -> b -> a Form.t -> Tyxml.Html.doc)
      (url : string)
      : Dream.route
    =
    url |> ignore;
    success_url |> ignore;
    on_valid |> ignore;
    on_invalid |> ignore;
    form |> ignore;
    template |> ignore;
    Dream.scope
      "/"
      []
      [ Dream.get url (fun _ -> Dream.respond "hello")
      ; Dream.post url (fun _ -> Dream.respond "hello")
      ]
  ;;

  let create () : string -> Dream.route =
   fun url -> Dream.get url (fun _ -> Dream.respond "foo")
 ;;

  let list () : string -> Dream.route =
   fun url -> Dream.get url (fun _ -> Dream.respond "foo")
 ;;

  let details () : string -> Dream.route =
   fun url -> Dream.get url (fun _ -> Dream.respond "foo")
 ;;
end
