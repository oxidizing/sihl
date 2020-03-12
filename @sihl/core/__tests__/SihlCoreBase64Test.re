open Jest;
open Expect;

describe("Base64", () => {
  test("encodes string", () => {
    "123" |> SihlCoreBase64.encode |> expect |> toBe("MTIz")
  });
  test("decodes string", () => {
    "MTIz" |> SihlCoreBase64.decode |> expect |> toBe("123")
  });
  test("decodes encoded string yields string", () => {
    "123"
    |> SihlCoreBase64.encode
    |> SihlCoreBase64.decode
    |> expect
    |> toBe("123")
  });
});
