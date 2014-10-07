module.exports = {

  initialize: function (update, failure) {
    cordova.exec(update, failure, "ConnectblueSerial", "initialize", []);
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
