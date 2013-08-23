# Bluetooth Serial Plugin for PhoneGap

This plugin enables serial communication over BT 4.0 LE on iOS talking to serial devices connected to a ConnectBlue OLP421 serial to bluetooth device in low power mode

The interface is modeled after the [BluetoothSerial](https://github.com/don/BluetoothSerial) plugin and where the names match up, should behave similarly.

The big differences are with subscribe and unsubscribe and the lack of other read methods.  The reason for this is just simplicity.   Data streams from the
device and you have to be ready to consume it in your app.

# API

## Methods

- connectblueSerial.list
- connectblueSerial.connect
- connectblueSerial.disconnect
- connectblueSerial.write
- connectblueSerial.subscribe
- connectblueSerial.unsubscribe
- connectblueSerial.isConnected


