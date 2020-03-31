open Jest;
open Expect;

describe("Configuration", () => {
  test("merges", () => {
    let config1 = Js.Dict.fromList([("FOO", "value1"), ("BAR", "value2")]);
    let config2 =
      Js.Dict.fromList([("FOOZ", "value3"), ("FOOB", "value4")]);
    let expected =
      Js.Dict.fromList([
        ("FOO", "value1"),
        ("BAR", "value2"),
        ("FOOZ", "value3"),
        ("FOOB", "value4"),
      ]);
    Sihl.Core.Config.Configuration.merge(config1, config2)
    |> expect
    |> toEqual(expected);
  })
});

describe("Schema Type", () => {
  test("validate string", () => {
    let configuration =
      Js.Dict.fromList([("FOO", "value1"), ("BAR", "value2")]);
    Sihl.Core.Config.Schema.(
      Type.validate(string_("FOO"), configuration)
      |> expect
      |> toEqual(Ok())
    );
  });
  test("validate string with choices", () => {
    let configuration = Js.Dict.fromList([("FOO", "value1")]);
    Sihl.Core.Config.Schema.(
      Type.validate(
        string_(~choices=["value1", "value2"], "FOO"),
        configuration,
      )
      |> expect
      |> toEqual(Ok())
    );
  });
  test("validate string with choices fails", () => {
    let configuration = Js.Dict.fromList([("FOO", "value3")]);
    Sihl.Core.Config.Schema.(
      Type.validate(
        string_(~choices=["value1", "value2"], "FOO"),
        configuration,
      )
      |> expect
      |> toEqual(
           Error(
             "value not found in choices key=FOO, value=value3, choices=value1,value2",
           ),
         )
    );
  });
  test("validate required string without default value fails", () => {
    let configuration = Js.Dict.fromList([("BAR", "value")]);
    Sihl.Core.Config.Schema.(
      Type.validate(string_("FOO"), configuration)
      |> expect
      |> toEqual(Error("required configuration not provided key=FOO"))
    );
  });
  test("validate string with default value fails", () => {
    let configuration = Js.Dict.fromList([("BAR", "value")]);
    Sihl.Core.Config.Schema.(
      Type.validate(string_(~default="value", "FOO"), configuration)
      |> expect
      |> toEqual(Ok())
    );
  });
  test("validate bool", () => {
    let configuration = Js.Dict.fromList([("BAR", "true")]);
    Sihl.Core.Config.Schema.(
      Type.validate(bool_("BAR"), configuration) |> expect |> toEqual(Ok())
    );
  });
  test("validate bool fails", () => {
    let configuration = Js.Dict.fromList([("BAR", "123")]);
    Sihl.Core.Config.Schema.(
      Type.validate(bool_("BAR"), configuration)
      |> expect
      |> toEqual(Error("provided configuration is not a bool key=BAR"))
    );
  });
  test("validate int", () => {
    let configuration = Js.Dict.fromList([("BAR", "123")]);
    Sihl.Core.Config.Schema.(
      Type.validate(int_("BAR"), configuration) |> expect |> toEqual(Ok())
    );
  });
  test("validate int fails", () => {
    let configuration = Js.Dict.fromList([("BAR", "123f")]);
    Sihl.Core.Config.Schema.(
      Type.validate(int_("BAR"), configuration)
      |> expect
      |> toEqual(
           Error("provided configuration is not an int key=BAR, value=123f"),
         )
    );
  });
});

describe("Schema", () => {
  test("validate one schema with valid configuration", () => {
    open Sihl.Core.Config.Schema;
    let schemas = [[string_("FOO"), bool_("BAR")]];
    let configuration =
      Js.Dict.fromList([("FOO", "value1"), ("BAR", "true")]);
    validate(schemas, configuration) |> expect |> toEqual(Ok(configuration));
  });
  test("validate one schema with invalid configuration", () => {
    open Sihl.Core.Config.Schema;
    let schemas = [[string_("FOO"), bool_("BAR")]];
    let configuration =
      Js.Dict.fromList([("FOO", "value1"), ("BAR", "123")]);
    validate(schemas, configuration)
    |> expect
    |> toEqual(Error("provided configuration is not a bool key=BAR"));
  });
});
