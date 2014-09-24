cordova.define('ConnectblueSerial', function (require, exports, module) {
  module.exports = {

    getState: function (success, failure) {
      cordova.exec(success, failure, "ConnectblueSerial", "getState", []);
    },

    scan: function (update, failure) {
      cordova.exec(update, failure, "ConnectblueSerial", "scan", []);
    },

    stopScan: function (success, failure) {
      cordova.exec(success, failure, "ConnectblueSerial", "stopScan", []);
    },

    connect: function (uuid, success, failure) {
      cordova.exec(success, failure, "ConnectblueSerial", "connect", [uuid]);
    },

    disconnect: function (success, failure) {
      cordova.exec(success, failure, "ConnectblueSerial", "disconnect", []);
    },

    write: function (data, success, failure) {
      cordova.exec(success, failure, "ConnectblueSerial", "write", [data]);
    },

    subscribe: function (update, failure) {
      cordova.exec(update, failure, "ConnectblueSerial", "subscribe", []);
    },

    unsubscribe: function (success, failure) {
      cordova.exec(success, failure, "ConnectblueSerial", "unsubscribe", []);
    }

  };
});
