"use strict";

const apiHandler = (payload, context, callback) => {
  callback(null, {
    statusCode: 200,
    body: {
      message: "Hello from Lambda to create",
    },
    headers: {
      "content-type": "*/*",
    },
  });
};

module.exports = {
  apiHandler,
};
