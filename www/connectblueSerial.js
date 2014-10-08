module.exports = {

  initialize: function (update) {
    cordova.exec(update, this._onError, "ConnectblueSerial", "initialize", []);
  },

  scan: function () {
    cordova.exec(this._onWtf, this._onError, "ConnectblueSerial", "scan", []);
  },

  stopScan: function () {
    cordova.exec(this._onWtf, this._onError, "ConnectblueSerial", "stopScan", []);
  },

  connect: function (uuid) {
    cordova.exec(this._onWtf, this._onError, "ConnectblueSerial", "connect", [uuid]);
  },

  disconnect: function () {
    cordova.exec(this._onWtf, this._onError, "ConnectblueSerial", "disconnect", []);
  },

  write: function (data) {
    cordova.exec(this._onWtf, this._onError, "ConnectblueSerial", "write", [data]);
  },

  _onError: function (message) { throw new Error(message); },
  _onWtf: function () { throw new Error("WTF?"); }

};
