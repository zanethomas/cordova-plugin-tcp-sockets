/**
 * Copyright (c) 2015, Blocshop s.r.o.
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms are permitted
 * provided that the above copyright notice and this paragraph are
 * duplicated in all such forms and that any documentation,
 * advertising materials, and other materials related to such
 * distribution and use acknowledge that the software was developed
 * by the Blocshop s.r.o.. The name of the
 * Blocshop s.r.o. may not be used to endorse or promote products derived
 * from this software without specific prior written permission.
 * THIS SOFTWARE IS PROVIDED ``AS IS'' AND WITHOUT ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.
 */

"use strict";

//var exec = require("cordova/exec");

var SOCKET_EVENT = "SOCKET_EVENT";
var SOCKET_SERVER_EVENT = "SOCKET_SERVER_EVENT";
var CORDOVA_SERVICE_NAME = "SocketsForCordova";

Socket.State = {};
Socket.State[Socket.State.CLOSED = 0] = "CLOSED";
Socket.State[Socket.State.OPENING = 1] = "OPENING";
Socket.State[Socket.State.OPENED = 2] = "OPENED";
Socket.State[Socket.State.CLOSING = 3] = "CLOSING";

ServerSocket.State = {};
ServerSocket.State[ServerSocket.State.STOPPED = 0] = "STOPPED";
ServerSocket.State[ServerSocket.State.STARTING = 1] = "STARTING";
ServerSocket.State[ServerSocket.State.STARTED = 2] = "STARTED";
ServerSocket.State[ServerSocket.State.STOPPING = 3] = "STOPPING";

function Socket(socketKey) {
    this._state = Socket.State.CLOSED;
    this.onData = null;
    this.onClose = null;
    this.onError = null;
    this.socketKey = socketKey || guid();
}

function ServerSocket(serverSocketKey) {
    this._state = ServerSocket.State.STOPPED;
    this.onOpened = null;
    this.onStopped = null;
    this.serverSocketKey = serverSocketKey || guid();
}

ServerSocket.prototype.start = function (iface, port, success, error) {
    success = success || (() => {});
    error = error || (() => {});

    if (!this._ensureState(ServerSocket.State.STOPPED, error)) {
        return;
    }

    var socketServerEventHandler = (event) => {
        var payload = event.payload;

        if (payload.serverSocketKey !== this.serverSocketKey) {
            return;
        }

        switch (payload.type) {
        case "Connected":
            var socket = new Socket(payload.socketKey);

            var socketEventHandler = (event) => {
                var payload = event.payload;

                if (payload.socketKey !== socket.socketKey) {
                    return;
                }

                switch (payload.type) {
                case "Close":
                    socket._state = Socket.State.CLOSED;
                    window.document.removeEventListener(SOCKET_EVENT, socketEventHandler);
                    if (socket.onClose) {
                        socket.onClose(payload.hasError);
                    }
                    break;
                case "DataReceived":
                    if (socket.onData) {
                        socket.onData(new Uint8Array(payload.data));
                    }
                    break;
                case "Error":
                    if (socket.onError) {
                        socket.onError(payload.errorMessage);
                    }
                    break;
                default:
                    console.error("SocketsForCordova: Unknown event type " + payload.type + ", socket key: " + payload.socketKey);
                    break;
                }
            };

            socket._state = Socket.State.OPENED;
            window.document.addEventListener(SOCKET_EVENT, socketEventHandler);

            if (this.onOpened) {
                this.onOpened(socket);
            }
            break;
        case "Stopped":
            this._state = ServerSocket.State.STOPPED;
            window.document.removeEventListener(SOCKET_SERVER_EVENT, socketServerEventHandler);
            if (this.onStopped) {
                this.onStopped(payload.hasError);
            }
            break;
        default:
            console.error("SocketsForCordova: Unknown event type " + payload.type + ", socket key: " + payload.socketKey);
            break;
        }
    };

    this._state = ServerSocket.State.STARTING;

    cordova.exec(
        () => {
            this._state = ServerSocket.State.STARTED;
            window.document.addEventListener(SOCKET_SERVER_EVENT, socketServerEventHandler);
            success();
        },
        (errorMessage) => {
            this._state = ServerSocket.State.STOPPED;
            error(errorMessage);
        },
        CORDOVA_SERVICE_NAME,
        "startServer",
        [ this.serverSocketKey, iface, port ]
    );
};

ServerSocket.prototype.startAsync = function (iface, port) {
    return new Promise((resolve, reject) => {
        return this.start(iface, port, resolve, reject);
    });
};

ServerSocket.prototype.stop = function (success, error) {
    success = success || (() => {});
    error = error || (() => {});

    if (!this._ensureState(ServerSocket.State.STARTED, error)) {
        return;
    }

    this._state = ServerSocket.State.STOPPING;

    cordova.exec(
        success,
        error,
        CORDOVA_SERVICE_NAME,
        "stopServer",
        [ this.serverSocketKey ]
    );
};

ServerSocket.prototype.stopAsync = function () {
    return new Promise((resolve, reject) => {
        return this.stop(resolve, reject);
    });
};

Socket.prototype.open = function (host, port, success, error) {
    success = success || (() => {});
    error = error || (() => {});

    if (!this._ensureState(Socket.State.CLOSED, error)) {
        return;
    }

    var socketEventHandler = (event) => {
        var payload = event.payload;

        if (payload.socketKey !== this.socketKey) {
            return;
        }

        switch (payload.type) {
        case "Close":
            this._state = Socket.State.CLOSED;
            window.document.removeEventListener(SOCKET_EVENT, socketEventHandler);
            if (this.onClose) {
                this.onClose(payload.hasError);
            }
            break;
        case "DataReceived":
            if (this.onData) {
                this.onData(new Uint8Array(payload.data));
            }
            break;
        case "Error":
            if (this.onError) {
                this.onError(payload.errorMessage);
            }
            break;
        default:
            console.error("SocketsForCordova: Unknown event type " + payload.type + ", socket key: " + payload.socketKey);
            break;
        }
    };

    this._state = Socket.State.OPENING;

    cordova.exec(
        () => {
            this._state = Socket.State.OPENED;
            window.document.addEventListener(SOCKET_EVENT, socketEventHandler);
            success();
        },
        (errorMessage) => {
            this._state = Socket.State.CLOSED;
            error(errorMessage);
        },
        CORDOVA_SERVICE_NAME,
        "open",
        [ this.socketKey, host, port ]
    );
};

Socket.prototype.openAsync = function (host, port) {
    return new Promise((resolve, reject) => {
        return this.open(host, port, resolve, reject);
    });
};

Socket.prototype.write = function (data, success, error) {
    success = success || (() => {});
    error = error || (() => {});

    if (!this._ensureState(Socket.State.OPENED, error)) {
        return;
    }

    var dataToWrite = data instanceof Uint8Array
        ? Socket._copyToArray(data)
        : data;

    cordova.exec(
        success,
        error,
        CORDOVA_SERVICE_NAME,
        "write",
        [ this.socketKey, dataToWrite ]
    );
};

Socket.prototype.writeAsync = function (data) {
    return new Promise((resolve, reject) => {
        return this.write(data, resolve, reject);
    });
};

Socket.prototype.shutdownWrite = function (success, error) {
    success = success || (() => {});
    error = error || (() => {});

    if (!this._ensureState(Socket.State.OPENED, error)) {
        return;
    }

    cordova.exec(
        success,
        error,
        CORDOVA_SERVICE_NAME,
        "shutdownWrite",
        [ this.socketKey ]
    );
};

Socket.prototype.shutdownWriteAsync = function () {
    return new Promise((resolve, reject) => {
        return this.shutdownWrite(resolve, reject);
    });
};

Socket.prototype.close = function (success, error) {
    success = success || (() => {});
    error = error || (() => {});

    if (!this._ensureState(Socket.State.OPENED, error)) {
        return;
    }

    this._state = Socket.State.CLOSING;

    cordova.exec(
        success,
        error,
        CORDOVA_SERVICE_NAME,
        "close",
        [ this.socketKey ]
    );
};

Socket.prototype.closeAsync = function () {
    return new Promise((resolve, reject) => {
        return this.close(resolve, reject);
    });
};

Object.defineProperty(Socket.prototype, "state", {
    get: function () {
        return this._state;
    },
    enumerable: true,
    configurable: true
});

Object.defineProperty(ServerSocket.prototype, "state", {
    get: function () {
        return this._state;
    },
    enumerable: true,
    configurable: true
});

Socket.prototype._ensureState = function(requiredState, errorCallback) {
    var state = this._state;
    if (state != requiredState) {
        window.setTimeout(function() {
            errorCallback("Invalid operation for this socket state: " + Socket.State[state]);
        });
        return false;
    }
    else {
        return true;
    }
};

ServerSocket.prototype._ensureState = function(requiredState, errorCallback) {
    var state = this._state;
    if (state != requiredState) {
        window.setTimeout(function() {
            errorCallback("Invalid operation for this socket state: " + ServerSocket.State[state]);
        });
        return false;
    }
    else {
        return true;
    }
};

Socket.dispatchEvent = function (event) {
    var eventReceive = document.createEvent("Events");
    eventReceive.initEvent(SOCKET_EVENT, true, true);
    eventReceive.payload = event;

    document.dispatchEvent(eventReceive);
};

ServerSocket.dispatchEvent = function (event) {
    var eventReceive = document.createEvent("Events");
    eventReceive.initEvent(SOCKET_SERVER_EVENT, true, true);
    eventReceive.payload = event;

    document.dispatchEvent(eventReceive);
};

Socket._copyToArray = function (array) {
    var outputArray = new Array(array.length);
    for (var i = 0; i < array.length; i++) {
        outputArray[i] = array[i];
    }
    return outputArray;
};

var guid = (function () {
    function s4() {
        return Math.floor((1 + Math.random()) * 0x10000)
            .toString(16)
            .substring(1);
    }

    return function () {
        return s4() + s4() + "-" + s4() + "-" + s4() + "-" +
            s4() + "-" + s4() + s4() + s4();
    };
})();

// Register event dispatcher for Windows Phone
if (navigator.userAgent.match(/iemobile/i)) {
    window.document.addEventListener("deviceready", function () {
        cordova.exec(
            Socket.dispatchEvent,
            function (errorMessage) {
                console.error("SocketsForCordova: Cannot register WP event dispatcher, Error: " + errorMessage);
            },
            CORDOVA_SERVICE_NAME,
            "registerWPEventDispatcher",
            [ ]);
    });
}

module.exports = {
    Socket,
    ServerSocket
};
