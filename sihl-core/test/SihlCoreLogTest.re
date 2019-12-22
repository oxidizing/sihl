open BsMocha;
let (describe, it, it_only) = Mocha.(describe, it, it_only);

describe("Log", () =>
  it("logs in the correct order", () => {
    Sihl.Core.Log.info("first", ());
    Sihl.Core.Log.warn("second", ());
    Sihl.Core.Log.error("last", ());
  })
);
