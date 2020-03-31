open Jest;
open Expect;

describe("Configuration", () => {
  test("merges with duplicated key fails", () => {
    let config1 = Js.Dict.fromList([("FOO", "VALUE1"), ("BAR", "VALUE2")]);
    let config2 = Js.Dict.fromList([("FOOZ", "VALUE3"), ("FOO", "VALUE4")]);
    Sihl.Core.Config.Configuration.merge(config1, config2)
    |> expect
    |> toEqual(
         Error(
           "Can not merge configurations, found duplicate configuration=FOO",
         ),
       );
  });
  test("merges", () => {
    let config1 = Js.Dict.fromList([("FOO", "VALUE1"), ("BAR", "VALUE2")]);
    let config2 =
      Js.Dict.fromList([("FOOZ", "VALUE3"), ("FOOB", "VALUE4")]);
    let expected =
      Js.Dict.fromList([
        ("FOO", "VALUE1"),
        ("BAR", "VALUE2"),
        ("FOOZ", "VALUE3"),
        ("FOOB", "VALUE4"),
      ]);
    Sihl.Core.Config.Configuration.merge(config1, config2)
    |> expect
    |> toEqual(Ok(expected));
  });
});
