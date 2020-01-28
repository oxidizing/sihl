open BsMocha;
let (describe, it, it_only) = Mocha.(describe, it, it_only);

describe("Log", () =>
  it("logs in the correct order", () => {
    SihlCore.Log.info("first", ());
    SihlCore.Log.warn("second", ());
    SihlCore.Log.error("last", ());
  })
);
