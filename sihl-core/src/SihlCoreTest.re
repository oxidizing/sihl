[%raw "require('isomorphic-fetch')"];
open Jest;
module Async = SihlCoreAsync;

module Integration = {
  let setupHarness = app => {
    beforeAllPromise(_ => SihlCoreMain.Manager.start(app));
    beforeEachPromise(_ => SihlCoreMain.Manager.clean());
    afterAllPromise(_ => SihlCoreMain.Manager.stop());
  };
};
