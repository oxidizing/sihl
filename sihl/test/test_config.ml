module Config = Sihl.Core.Config
open Base
open Config.Schema

module Schema = struct
  let test_validate_string () =
    let configuration =
      Config.of_list [ ("FOO", "value1"); ("BAR", "value2") ]
      |> Result.ok_or_failwith
    in
    let actual = Type.validate (string_ "FOO") configuration in
    Alcotest.(check @@ result unit string) "validates string" (Ok ()) actual

  let test_validate_existing_required_if_string () =
    let configuration =
      Config.of_list [ ("FOO", "value1"); ("BAR", "value2") ]
      |> Result.ok_or_failwith
    in
    let actual =
      Type.validate (string_ ~required_if:("BAR", "value2") "FOO") configuration
    in
    Alcotest.(check @@ result unit string)
      "validates string with required if" (Ok ()) actual

  let test_validate_required_if_non_existing_string_fails () =
    let configuration =
      Config.of_list [ ("BAR", "value2") ] |> Result.ok_or_failwith
    in
    let actual =
      Type.validate (string_ ~required_if:("BAR", "value2") "FOO") configuration
    in
    Alcotest.(check @@ result unit string)
      "validates string with non-existing required if fails"
      (Error
         "required configuration because of dependency not found \
          required_config=(BAR, value2), key=FOO") actual

  let test_validate_non_existing_required_if_string () =
    let configuration =
      Config.of_list [ ("BAR", "value2") ] |> Result.ok_or_failwith
    in
    let actual =
      Type.validate
        (string_ ~required_if:("BAR", "othervalue") "FOO")
        configuration
    in
    Alcotest.(check @@ result unit string)
      "validates non-existing required if string" (Ok ()) actual

  let test_validate_string_with_choices () =
    let configuration =
      Config.of_list [ ("FOO", "value1") ] |> Result.ok_or_failwith
    in
    let actual =
      Type.validate
        (string_ ~choices:[ "value1"; "value2" ] "FOO")
        configuration
    in
    Alcotest.(check @@ result unit string)
      "validates string with choices" (Ok ()) actual

  let test_validate_string_with_choices_fails () =
    let configuration =
      Config.of_list [ ("FOO", "value3") ] |> Result.ok_or_failwith
    in
    let actual =
      Type.validate
        (string_ ~choices:[ "value1"; "value2" ] "FOO")
        configuration
    in
    Alcotest.(check @@ result unit string)
      "validates string with choices fails"
      (Error
         "value not found in choices key=FOO, value=value3, choices=value1, \
          value2") actual

  let test_validate_required_string_without_default_fails () =
    let configuration =
      Config.of_list [ ("BAR", "value") ] |> Result.ok_or_failwith
    in
    let actual = Type.validate (string_ "FOO") configuration in
    Alcotest.(check @@ result unit string)
      "validates required string without default fails"
      (Error "required configuration not provided key=FOO") actual

  let test_validate_string_with_default () =
    let configuration =
      Config.of_list [ ("BAR", "value") ] |> Result.ok_or_failwith
    in
    let actual = Type.validate (string_ "FOO" ~default:"value") configuration in
    Alcotest.(check @@ result unit string)
      "validates required string with default" (Ok ()) actual

  let test_validate_bool () =
    let configuration =
      Config.of_list [ ("BAR", "true") ] |> Result.ok_or_failwith
    in
    let actual = Type.validate (bool_ "BAR") configuration in
    Alcotest.(check @@ result unit string) "validates bool" (Ok ()) actual

  let test_validate_bool_fails () =
    let configuration =
      Config.of_list [ ("BAR", "123") ] |> Result.ok_or_failwith
    in
    let actual = Type.validate (bool_ "BAR") configuration in
    Alcotest.(check @@ result unit string)
      "validates bool fails"
      (Error "provided configuration is not a bool key=BAR, value=123") actual

  let test_validate_existing_required_if_bool () =
    let configuration =
      Config.of_list [ ("FOO", "true"); ("BAR", "value2") ]
      |> Result.ok_or_failwith
    in
    let actual =
      Type.validate (bool_ ~required_if:("BAR", "value2") "FOO") configuration
    in
    Alcotest.(check @@ result unit string)
      "validates bool with required if" (Ok ()) actual

  let test_validate_existing_required_if_bool_fails () =
    let configuration =
      Config.of_list [ ("FOO", "123"); ("BAR", "value2") ]
      |> Result.ok_or_failwith
    in
    let actual =
      Type.validate (bool_ ~required_if:("BAR", "value2") "FOO") configuration
    in
    Alcotest.(check @@ result unit string)
      "validates bool with required if fails"
      (Error "provided configuration is not a bool key=FOO, value=123") actual

  let test_validate_int () =
    let configuration =
      Config.of_list [ ("BAR", "123") ] |> Result.ok_or_failwith
    in
    let actual = Type.validate (int_ "BAR") configuration in
    Alcotest.(check @@ result unit string) "validates int" (Ok ()) actual

  let test_validate_int_fails () =
    let configuration =
      Config.of_list [ ("BAR", "123f") ] |> Result.ok_or_failwith
    in
    let actual = Type.validate (int_ "BAR") configuration in
    Alcotest.(check @@ result unit string)
      "validates int fails"
      (Error "provided configuration is not an int key=BAR, value=123f") actual

  let test_process_valid_config () =
    let schemas = [ [ string_ "FOO"; bool_ "BAR" ] ] in
    let setting =
      Config.Setting.create
        ~test:[ ("FOO", "value1"); ("BAR", "true") ]
        ~development:[] ~production:[]
    in
    let expected =
      Config.of_list [ ("FOO", "value1"); ("BAR", "true") ]
      |> Result.ok_or_failwith
    in
    let actual = Config.process schemas setting |> Result.ok_or_failwith in
    let are_identical = Map.equal String.equal actual expected in
    Alcotest.(check bool) "process config" true are_identical

  let test_process_invalid_config_fails () =
    let schemas = [ [ string_ "FOO"; bool_ "BAR" ] ] in
    let setting =
      Config.Setting.create
        ~test:[ ("FOO", "value1"); ("BAR", "123") ]
        ~development:[] ~production:[]
    in
    let actual =
      Config.process schemas setting |> Result.map ~f:(fun _ -> ())
    in
    Alcotest.(check @@ result unit string)
      "process invalid config fails"
      (Error "provided configuration is not a bool key=BAR, value=123") actual
end
