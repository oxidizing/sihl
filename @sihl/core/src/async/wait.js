module.exports = (ms) => {
  return new Promise((res, rej) => {
    setTimeout(res, ms);
  });
};
