module.exports = (middleware, req, res) => {
  return new Promise((resolve, reject) => {
    let next = () => {
      resolve();
    };
    middleware(req, res, next);
  });
};
