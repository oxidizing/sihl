open Jest;

Expect.(
  test("Logging", () => {
    SihlCoreLog.info("first", ());
    SihlCoreLog.warn("second", ());
    SihlCoreLog.error("last", ());
    true |> expect |> ExpectJs.toBeTruthy;
  })
);
