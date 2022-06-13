type widget = TextArea

type field =
  { typ : Model.field
  ; widget : widget option
  ; value : string option
  ; errors : string list
  }

(* TODO consider other names: dirty *)
type 'a unsafe = ('a, field) Model.record
type 'a valid = 'a * ('a, field) Model.record
type 'a invalid = string * ('a, field) Model.record
type 'a validated = ('a valid, 'a invalid) Result.t

type 'a t =
  | Unsafe of 'a unsafe
  | Validated of 'a validated

type generic =
  { name : string
  ; fields : field list
  }

let generic (form : 'a unsafe) : generic =
  { name = form.name; fields = form.fields }
;;

let int
    ?widget
    ?default
    ?nullable
    (record_field : ('perm, 'record, int) Model.record_field)
    : field
  =
  { typ = Model.int ?default ?nullable record_field
  ; widget
  ; value = None
  ; errors = []
  }
;;

let timestamp
    ?widget
    ?default
    ?nullable
    ?update
    (record_field : ('perm, 'record, Ptime.t) Model.record_field)
    : field
  =
  { typ = Model.timestamp ?default ?nullable ?update record_field
  ; widget
  ; value = None
  ; errors = []
  }
;;

let string
    ?widget
    ?default
    ?nullable
    (record_field : ('perm, 'record, string) Model.record_field)
    : field
  =
  { typ = Model.string ?default ?nullable record_field
  ; widget
  ; value = None
  ; errors = []
  }
;;

let validate_form (form : 'a unsafe) : 'a unsafe =
  let schema_field_names =
    List.map (fun { typ; _ } -> Model.field_name typ) form.fields
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
    (fields : field list)
    : 'a unsafe
  =
  let form : 'a unsafe =
    { name; fields; field_names; to_yojson; of_yojson; validate }
  in
  let form : 'a unsafe = form |> validate_form in
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
  let input_fields : field list =
    record.fields
    |> List.map (fun (Model.AnyField (name, _) as field) ->
           { typ = field
           ; widget =
               List.find_opt
                 (fun (record_field, _) ->
                   String.equal (Fieldslib.Field.name record_field) name)
                 widgets
               |> Option.map snd
           ; value = None
           ; errors = []
           })
  in
  let form : 'a unsafe =
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

let validate (_ : 'a unsafe) (_ : (string * string) list) : 'a validated =
  failwith "validate()"
;;

let render (_ : 'a t) : _ Tyxml.Html.elt = failwith "render()"
