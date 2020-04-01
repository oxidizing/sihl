module.exports = (n, encoding) => {
  return new Promise((resolve, reject) => {
    require('crypto').randomBytes(n, function(err, buffer) {
      if (err) {
        reject(err);
      } else {
        resolve(buffer.toString(encoding));
      }
    });
});
};
