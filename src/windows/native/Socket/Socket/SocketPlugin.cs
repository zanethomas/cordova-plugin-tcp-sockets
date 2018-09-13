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

using System;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using Windows.Foundation;
using Windows.Data.Json;
using Windows.UI.Core;
using Windows.Networking.Sockets;

namespace Blocshop.ScoketsForCordova
{
    public sealed class SocketPlugin
    {
        public event EventHandler<string> MessageReceived;
        public event EventHandler<string> ServerMessageReceived;

        internal delegate Task DataConsumeDelegate(string socketKey, byte[] data);
        internal delegate Task CloseEventDelegate(string socketKey, bool hasError);
        internal delegate Task ErrorDelegate(string socketKey, Exception ex);
        internal DataConsumeDelegate dataConsumeDelegate;
        internal CloseEventDelegate closeEventDelegate;
        internal ErrorDelegate errorDelegate;

        private readonly ISocketStorage socketStorage;
        private CoreDispatcher dispatcher;

        public SocketPlugin()
        {
            socketStorage = SocketStorage.CreateSocketStorage();
            dispatcher = CoreWindow.GetForCurrentThread().Dispatcher;
            dataConsumeDelegate = DataConsumer;
            closeEventDelegate = CloseEventHandler;
            errorDelegate = ErrorHandler;
        }

        public IAsyncOperation<string> open(string parameters)
        {
            string socketKey = JsonArray.Parse(parameters).ElementAt(0).GetString();
            string host = JsonArray.Parse(parameters).ElementAt(1).GetString();
            int port = Convert.ToInt32(JsonArray.Parse(parameters).ElementAt(2).GetNumber());

            return OpenTask(socketKey, host, port).AsAsyncOperation();
        }

        public IAsyncOperation<string> write(string parameters)
        {
            string socketKey = JsonArray.Parse(parameters).ElementAt(0).GetString();
            string dataJsonArray = JsonArray.Parse(parameters).ElementAt(1).GetString();
            byte[] data = Encoding.UTF8.GetBytes(dataJsonArray);

            return WriteTask(socketKey, data).AsAsyncOperation();
        }

        public void shutdownWrite(string parameters)
        {
            string socketKey = parameters;

            ISocketAdapter socket = socketStorage.Get(socketKey);

            socket.ShutdownWrite();
        }

        public void close(string parameters)
        {
            string socketKey = parameters;

            ISocketAdapter socket = socketStorage.Get(socketKey);

            socket.Close();
        }

        public IAsyncOperation<string> startServer(string parameters)
        {
            string serverSocketKey = JsonArray.Parse(parameters).ElementAt(0).GetString();
            string iface = JsonArray.Parse(parameters).ElementAt(1).GetString();
            int port = Convert.ToInt32(JsonArray.Parse(parameters).ElementAt(2).GetNumber());

            return StartServerTask(serverSocketKey, iface, port).AsAsyncOperation();
        }

        public void stopServer(string parameters)
        {
            string socketKey = parameters;
            var socketServer = socketStorage.GetServerSocket(socketKey);
            socketServer.Stop();
        }

        private async Task<string> WriteTask(string socketKey, byte[] data)
        {
            ISocketAdapter socket = socketStorage.Get(socketKey);
            PluginResult result = new PluginResult();

            await Task.Run(async () =>
            {
                try
                {
                    await socket.Write(data);
                    result.Result = PluginResult.Status.OK;
                }
                catch (Exception ex)
                {
                    result.Result = PluginResult.Status.IO_EXCEPTION;
                    result.Message = ex.Message;
                }
            });

            JsonObject jsonObject = new JsonObject();
            jsonObject.SetNamedValue("Result", JsonValue.CreateNumberValue((int)result.Result));
            if (result.Message != null)
                jsonObject.SetNamedValue("Message", JsonValue.CreateStringValue(result.Message));

            return jsonObject.ToString();
        }

        private async Task<string> OpenTask(string socketKey, string host, int port)
        {
            PluginResult result = new PluginResult();
            await Task.Run(async () =>
            {
                ISocketAdapter socketAdapter = new SocketAdapter();
                socketAdapter.CloseEventHandler = async (hasError) => await closeEventDelegate(socketKey, hasError);
                socketAdapter.DataConsumer = async (data) => await dataConsumeDelegate(socketKey, data.ToArray());
                socketAdapter.ErrorHandler = async (ex) => await errorDelegate(socketKey, ex);

                try
                {
                    await socketAdapter.Connect(host, port);
                    socketStorage.Add(socketKey, socketAdapter);
                    result.Result = PluginResult.Status.OK;
                }
                catch (AggregateException ex)
                {
                    result.Result = PluginResult.Status.IO_EXCEPTION;
                    result.Message = ex.InnerException.Message;
                }
                catch (Exception ex)
                {
                    result.Result = PluginResult.Status.IO_EXCEPTION;
                    result.Message = ex.Message;
                }
            });

            JsonObject jsonObject = new JsonObject();
            jsonObject.SetNamedValue("Result", JsonValue.CreateNumberValue((int)result.Result));
            if (result.Message != null)
                jsonObject.SetNamedValue("Message", JsonValue.CreateStringValue(result.Message));

            return jsonObject.ToString();
        }

        private async Task<string> StartServerTask(string serverSocketKey, string iface, int port)
        {
            PluginResult result = new PluginResult();

            try
            {
                ISocketServerAdapter socketServerAdapter = new SocketServerAdapter(socketStorage, dataConsumeDelegate, closeEventDelegate, errorDelegate);

                socketServerAdapter.StoppedEventHandler = async (hasError) => await StoppedEventHandler(serverSocketKey, hasError);
                socketServerAdapter.OpenedEventHandler = async (socketKey) => await OpenedEventHandler(serverSocketKey, socketKey);

                socketStorage.AddServerSocket(serverSocketKey, socketServerAdapter);
                socketServerAdapter.Start(iface, port);
                result.Result = PluginResult.Status.OK;
            }
            catch (Exception ex)
            {
                SocketErrorStatus webErrorStatus = Windows.Networking.Sockets.SocketError.GetStatus(ex.GetBaseException().HResult);
                var message = webErrorStatus.ToString() != "Unknown" ? webErrorStatus.ToString() : ex.Message;
                result.Result = PluginResult.Status.IO_EXCEPTION;
                result.Message = message;
            }

            JsonObject jsonObject = new JsonObject();
            jsonObject.SetNamedValue("Result", JsonValue.CreateNumberValue((int)result.Result));
            if (result.Message != null)
                jsonObject.SetNamedValue("Message", JsonValue.CreateStringValue(result.Message));

            return jsonObject.ToString();
        }

        private async Task CloseEventHandler(string socketKey, bool hasError)
        {
            socketStorage.Remove(socketKey);
            var socketEvent = new CloseSocketEvent
            {
                HasError = hasError,
                SocketKey = socketKey
            };

            try
            {
                JsonObject jsonObject = new JsonObject();
                jsonObject.SetNamedValue("hasError", JsonValue.CreateBooleanValue(socketEvent.HasError));
                jsonObject.SetNamedValue("socketKey", JsonValue.CreateStringValue(socketEvent.SocketKey));
                jsonObject.SetNamedValue("type", JsonValue.CreateStringValue(socketEvent.Type));

                var message = jsonObject.ToString();

                await DispatchEvent(message);
            }
            catch (Exception ex)
            {
                await DispatchEvent(ex.Message + " " + ex.InnerException);
            }
        }

        private async Task DataConsumer(string socketKey, byte[] data)
        {
            var socketEvent = new DataReceivedSocketEvent
            {
                Data = data,
                SocketKey = socketKey
            };

            try
            {
                JsonObject jsonObject = new JsonObject();
                jsonObject.SetNamedValue("data", JsonValue.CreateStringValue(Encoding.UTF8.GetString(socketEvent.Data, 0, socketEvent.Data.Length)));
                jsonObject.SetNamedValue("socketKey", JsonValue.CreateStringValue(socketEvent.SocketKey));
                jsonObject.SetNamedValue("type", JsonValue.CreateStringValue(socketEvent.Type));

                var message = jsonObject.ToString();

                await DispatchEvent(message);
            }
            catch (Exception ex)
            {
                await DispatchEvent(ex.Message + " " + ex.InnerException);
            }
        }

        private async Task ErrorHandler(string socketKey, Exception exception)
        {
            var socketEvent = new ErrorSocketEvent
            {
                ErrorMessage = exception.Message,
                SocketKey = socketKey
            };

            try
            {
                JsonObject jsonObject = new JsonObject();
                jsonObject.SetNamedValue("errorMessage", JsonValue.CreateStringValue(socketEvent.ErrorMessage));
                jsonObject.SetNamedValue("socketKey", JsonValue.CreateStringValue(socketEvent.SocketKey));
                jsonObject.SetNamedValue("type", JsonValue.CreateStringValue(socketEvent.Type));

                var message = jsonObject.ToString();

                await DispatchEvent(message);
            }
            catch (Exception ex)
            {
                await DispatchEvent(ex.Message + " " + ex.InnerException);
            }
        }

        private async Task StoppedEventHandler(string socketServerKey, bool hasError)
        {
            var socketEvent = new StoppedSocketServerEvent
            {
                HasError = hasError,
                ServerSocketKey = socketServerKey
            };

            try
            {
                JsonObject jsonObject = new JsonObject();
                jsonObject.SetNamedValue("hasError", JsonValue.CreateBooleanValue(socketEvent.HasError));
                jsonObject.SetNamedValue("serverSocketKey", JsonValue.CreateStringValue(socketEvent.ServerSocketKey));
                jsonObject.SetNamedValue("type", JsonValue.CreateStringValue(socketEvent.Type));

                var message = jsonObject.ToString();

                await DispatchServerEvent(message);
            }
            catch (Exception ex)
            {
                await DispatchServerEvent(ex.Message + " " + ex.InnerException);
            }
        }

        private async Task OpenedEventHandler(string socketServerKey, string socketKey)
        {
            var socketEvent = new ConnectedSocketServerEvent
            {
                SocketKey = socketKey,
                ServerSocketKey = socketServerKey
            };

            try
            {
                JsonObject jsonObject = new JsonObject();
                jsonObject.SetNamedValue("socketKey", JsonValue.CreateStringValue(socketEvent.SocketKey));
                jsonObject.SetNamedValue("serverSocketKey", JsonValue.CreateStringValue(socketEvent.ServerSocketKey));
                jsonObject.SetNamedValue("type", JsonValue.CreateStringValue(socketEvent.Type));

                var message = jsonObject.ToString();

                await DispatchServerEvent(message);
            }
            catch (Exception ex)
            {
                await DispatchServerEvent(ex.Message + " " + ex.InnerException);
            }
        }

        private async Task DispatchEvent(string message)
        {
            if (MessageReceived != null)
            {
                await dispatcher.RunAsync(CoreDispatcherPriority.Normal,
                    new DispatchedHandler(() =>
                    {
                        MessageReceived?.Invoke(this, message);
                    }));
            }
        }

        private async Task DispatchServerEvent(string message)
        {
            if (ServerMessageReceived != null)
            {
                await dispatcher.RunAsync(CoreDispatcherPriority.Normal,
                    new DispatchedHandler(() =>
                    {
                        ServerMessageReceived?.Invoke(this, message);
                    }));
            }
        }
    }

    internal class PluginResult
    {
        public enum Status : int
        {
            NO_RESULT = 0,
            OK,
            CLASS_NOT_FOUND_EXCEPTION,
            ILLEGAL_ACCESS_EXCEPTION,
            INSTANTIATION_EXCEPTION,
            MALFORMED_URL_EXCEPTION,
            IO_EXCEPTION,
            INVALID_ACTION,
            JSON_EXCEPTION,
            ERROR
        };

        public Status Result { get; set; }
        public string Message { get; set; }
        public bool KeepCallback { get; set; }
        public string CallbackId { get; set; }
    }
}
