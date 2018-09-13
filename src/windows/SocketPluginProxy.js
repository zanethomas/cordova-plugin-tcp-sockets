    var cordova = require('cordova');
    var SocketsForCordova = require('./Socket');
    var socketPlugin;
    
        module.exports = {
            open: function (successCallback, errorCallback, parameters) {
                let args = JSON.stringify(parameters);
                if (socketPlugin === undefined) {
                    socketPlugin = new Blocshop.ScoketsForCordova.SocketPlugin();
                    socketPlugin.onmessagereceived = msg => {
                        if (msg.type === "DataReceived")
                            msg.data = encodeUTF8(msg.data);
                        SocketsForCordova.Socket.dispatchEvent(msg);
                    };
                    socketPlugin.onservermessagereceived = msg => {
                        SocketsForCordova.ServerSocket.dispatchEvent(msg);
                    };
                }
                socketPlugin.open(args).then(function (success) {
                    if (success && typeof success === 'string') {
                        success = JSON.parse(success);
                        if (success.Result === 1)
                            successCallback(success);
                        else
                            errorCallback(success);
                    }
                    
                }, function (error) {
                    errorCallback(error);
                });
            },
            write: function (successCallback, errorCallback, parameters) {
                let bytes = parameters[1];
                let bytesString = String.fromCharCode.apply(null, bytes);
                parameters[1] = bytesString;
                let args = JSON.stringify(parameters);
                socketPlugin.write(args).then(function (success) {
                    if (success && typeof success === 'string') {
                        success = JSON.parse(success);
                        if (success.Result === 1)
                            successCallback(success);
                        else
                            errorCallback(success);
                    }
                }, function (error) {
                    errorCallback(error);
                });
            },
            shutdownWrite: function (successCallback, errorCallback, parameters) {
                socketPlugin.shutdownWrite(parameters[0]);
                successCallback();
            },
            close: function (successCallback, errorCallback, parameters) {
                socketPlugin.close(parameters[0]);
                successCallback();
            },
            startServer: function (successCallback, errorCallback, parameters) {
                let args = JSON.stringify(parameters);
                if (socketPlugin === undefined) {
                    socketPlugin = new Blocshop.ScoketsForCordova.SocketPlugin();
                    socketPlugin.onmessagereceived = msg => {
                        let msgObj = JSON.parse(msg);
                        if (msgObj.type === "DataReceived")
                            msgObj.data = encodeUTF8(msgObj.data);
                        SocketsForCordova.Socket.dispatchEvent(msgObj);
                    };
                    socketPlugin.onservermessagereceived = msg => {
                        let msgObj = JSON.parse(msg);
                        SocketsForCordova.ServerSocket.dispatchEvent(msgObj);
                    };
                }
                socketPlugin.startServer(args).then(function (success) {
                    if (success && typeof success === 'string') {
                        success = JSON.parse(success);
                        if (success.Result === 1)
                            successCallback(success);
                        else
                            errorCallback(success);
                    }
                }, function (error) {
                    errorCallback(error);
                });
            },
            stopServer: function (successCallback, errorCallback, parameters) {
                socketPlugin.stopServer(parameters[0]);
                successCallback();
            }
        }

        require("cordova/exec/proxy").add("SocketsForCordova", module.exports);

        function encodeUTF8(s) {
            var i = 0, bytes = new Uint8Array(s.length * 4);
            for (var ci = 0; ci != s.length; ci++) {
                var c = s.charCodeAt(ci);
                if (c < 128) {
                    bytes[i++] = c;
                    continue;
                }
                if (c < 2048) {
                    bytes[i++] = c >> 6 | 192;
                } else {
                    if (c > 0xd7ff && c < 0xdc00) {
                        if (++ci >= s.length)
                            throw new Error('UTF-8 encode: incomplete surrogate pair');
                        var c2 = s.charCodeAt(ci);
                        if (c2 < 0xdc00 || c2 > 0xdfff)
                            throw new Error('UTF-8 encode: second surrogate character 0x' + c2.toString(16) + ' at index ' + ci + ' out of range');
                        c = 0x10000 + ((c & 0x03ff) << 10) + (c2 & 0x03ff);
                        bytes[i++] = c >> 18 | 240;
                        bytes[i++] = c >> 12 & 63 | 128;
                    } else bytes[i++] = c >> 12 | 224;
                    bytes[i++] = c >> 6 & 63 | 128;
                }
                bytes[i++] = c & 63 | 128;
            }
            return bytes.subarray(0, i);
        }
    

