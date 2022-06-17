module Model = Sihl__model.Model

type _ widget =
  | TextArea : string widget
  | Email : string widget
  | InputField : string widget
  | Date : Ptime.t widget
  | NumberInt : int widget
  | NumberFloat : float widget
  | Checkbox : bool widget
  | Select : { options : string list } -> string widget

type widget_any = Any : 'a widget -> widget_any

type field =
  { typ : Model.field
  ; widget : widget_any
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

let any (widget : 'a widget) : widget_any = Any widget

let generic (form : 'a unsafe) : generic =
  { name = form.name; fields = form.fields }
;;

let int
    ?(widget : int widget option)
    ?default
    ?nullable
    (record_field : ('perm, 'record, int) Model.record_field)
    : field
  =
  { typ = Model.int ?default ?nullable record_field
  ; widget = any (Option.value ~default:NumberInt widget)
  ; value = None
  ; errors = []
  }
;;

let timestamp
    ?(widget : Ptime.t widget option)
    ?default
    ?nullable
    ?update
    (record_field : ('perm, 'record, Ptime.t) Model.record_field)
    : field
  =
  { typ = Model.timestamp ?default ?nullable ?update record_field
  ; widget = any (Option.value ~default:Date widget)
  ; value = None
  ; errors = []
  }
;;

let text_area (record_field : ('perm, 'record, string) Model.record_field)
    : string * widget_any
  =
  Fieldslib.Field.name record_field, any TextArea
;;

let input_email
    ?default
    ?nullable
    (record_field : ('perm, 'record, string) Model.record_field)
    : field
  =
  { typ = Model.string ?default ?nullable record_field
  ; widget = any Email
  ; value = None
  ; errors = []
  }
;;

let input
    ?default
    ?nullable
    (record_field : ('perm, 'record, string) Model.record_field)
    : field
  =
  { typ = Model.string ?default ?nullable record_field
  ; widget = any InputField
  ; value = None
  ; errors = []
  }
;;

let input_int
    ?default
    ?nullable
    (record_field : ('perm, 'record, int) Model.record_field)
    : field
  =
  { typ = Model.string ?default ?nullable record_field
  ; widget = any NumberInt
  ; value = None
  ; errors = []
  }
;;

let input_float
    ?default
    ?nullable
    (record_field : ('perm, 'record, int) Model.record_field)
    : field
  =
  { typ = Model.string ?default ?nullable record_field
  ; widget = any NumberFloat
  ; value = None
  ; errors = []
  }
;;

let string
    ?(widget : string widget option)
    ?default
    ?nullable
    (record_field : ('perm, 'record, string) Model.record_field)
    : field
  =
  { typ = Model.string ?default ?nullable record_field
  ; widget = any (Option.value ~default:InputField widget)
  ; value = None
  ; errors = []
  }
;;

let input_date
    ?default
    ?nullable
    (record_field : ('perm, 'record, Ptime.t) Model.record_field)
    : field
  =
  { typ = Model.string ?default ?nullable record_field
  ; widget = any Date
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

let widget_of_typ = function
  | Model.AnyField (_, (_, Model.Integer _)) -> any NumberInt
  | Model.AnyField (_, (_, Model.Email _))
  | Model.AnyField (_, (_, Model.String _)) -> any InputField
  | Model.AnyField (_, (_, Model.Timestamp _)) -> any Date
  | Model.AnyField (_, (_, Model.Boolean _)) -> any Checkbox
  | Model.AnyField (_, (_, Model.Enum { all; to_yojson; _ })) ->
    (* consider https://github.com/janestreet/ppx_variants_conv *)
    let options = List.map (fun a -> a |> to_yojson |> Yojson.Safe.show) all in
    any (Select { options })
  | Model.AnyField (_, (_, Model.Foreign_key _)) ->
    failwith "widget for foreign key"
;;

let of_model ?(widgets : (string * widget_any) list = []) (model : 'a Model.t) =
  let _, record = model in
  let input_fields : field list =
    record.fields
    |> List.map (fun (Model.AnyField (name, _) as field) ->
           { typ = field
           ; widget =
               (match
                  List.find_opt
                    (fun (record_name, _) -> String.equal record_name name)
                    widgets
                  |> Option.map snd
                with
               | Some widget -> widget
               | None -> widget_of_typ field)
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

let render_field (field : field) : _ Tyxml.Html.elt =
  let open Tyxml.Html in
  let html =
    match field with
    | { typ = AnyField (name, (_, Model.Integer _))
      ; widget = Any NumberInt
      ; value
      ; errors
      } ->
      let has_errors = List.length errors > 0 in
      errors |> ignore;
      [ label [ txt name ]
      ; br ()
      ; input
          ~a:
            [ a_input_type `Number
            ; a_required ()
            ; a_value (Option.value value ~default:"")
            ; a_style (if has_errors then "border:red;" else "")
            ]
          ()
      ]
    | _ -> []
  in
  p html
;;

let render (form : 'a t) : _ Tyxml.Html.elt =
  match form with
  | Unsafe { fields; _ } -> Tyxml.Html.div @@ List.map render_field fields
  | Validated (Ok (_, { fields; _ })) ->
    Tyxml.Html.div @@ List.map render_field fields
  | Validated (Error (_, { fields; _ })) ->
    Tyxml.Html.div @@ List.map render_field fields
;;
