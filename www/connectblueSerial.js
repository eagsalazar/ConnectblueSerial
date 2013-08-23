cordova.define('connectblueSerial', function (require, exports, module) {
  module.exports = {

    // [
    //  {uuid: 'abdadflk', name: 'IonProbe1'},
    //  {uuid: 'abdadfll', name: 'IonProbe2'},
    //  {uuid: 'abdadflm', name: 'IonProbe3'}
    // ]
    list: function (success, failure) {
      cordova.exec(success, failure, "ConnectblueSerial", "list", []);
    },

    // Disconnects if already connected
    connect: function (uuid, success, failure) {
      cordova.exec(success, failure, "ConnectblueSerial", "connect", [uuid]);
    },

    disconnect: function (success, failure) {
      cordova.exec(success, failure, "ConnectblueSerial", "disconnect", []);
    },

    write: function (data, success, failure) {
      cordova.exec(success, failure, "ConnectblueSerial", "write", [data]);
    },

    // update is called every time there is new data
    subscribe: function (update, failure) {
      cordova.exec(update, failure, "ConnectblueSerial", "subscribe", []);
    },

    unsubscribe: function (success, failure) {
      cordova.exec(success, failure, "ConnectblueSerial", "unsubscribe", []);
    },

    isConnected: function (success, failure) {
      cordova.exec(success, failure, "ConnectblueSerial", "isConnected", []);
    }

  };
});
