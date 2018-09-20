    var cordova = require('cordova');
    var SocketsForCordova = require('./Socket');
    var socketPlugin;
    
        module.exports = {
            open: function (successCallback, errorCallback, parameters) {
                let args = JSON.stringify(parameters);
                if (socketPlugin === undefined) {
                    socketPlugin = new Blocshop.ScoketsForCordova.SocketPlugin();
                socketPlugin.ondatamessagereceived = msg => SocketsForCordova.Socket.dispatchEvent(msg.detail[0]);
                socketPlugin.onclosemessagereceived = msg => SocketsForCordova.Socket.dispatchEvent(msg.detail[0]);
                socketPlugin.onerrormessagereceived = msg => SocketsForCordova.Socket.dispatchEvent(msg.detail[0]);
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
            socketPlugin.write(parameters[0], parameters[1]).then(function (success) {
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
                socketPlugin.ondatamessagereceived = msg => SocketsForCordova.Socket.dispatchEvent(msg.detail[0]);
                socketPlugin.onclosemessagereceived = msg => SocketsForCordova.Socket.dispatchEvent(msg.detail[0]);
                socketPlugin.onerrormessagereceived = msg => SocketsForCordova.Socket.dispatchEvent(msg.detail[0]);
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
