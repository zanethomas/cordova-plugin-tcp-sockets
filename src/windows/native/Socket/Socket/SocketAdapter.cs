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
using System.Collections.Generic;
using System.IO;
using System.Threading.Tasks;
using Windows.Foundation;
using Windows.Networking;
using Windows.Networking.Sockets;

namespace Blocshop.ScoketsForCordova
{
    internal interface ISocketAdapter
    {
        IAsyncAction Connect(String host, int port);
        IAsyncAction Write(byte[] data);
        void ShutdownWrite();
        void Close();
        SocketAdapterOptions Options { get; set; }
        Action<IEnumerable<byte>> DataConsumer { get; set; }
        Action<bool> CloseEventHandler { get; set; }
        Action<Exception> ErrorHandler { get; set; }
    }


    internal class SocketAdapter : ISocketAdapter
    {
        private const int InputStreamBufferSize = 16 * 1024;
        private readonly StreamSocket socket;

        public Action<IEnumerable<byte>> DataConsumer { get; set; }
        public Action<bool> CloseEventHandler { get; set; }
        public Action<Exception> ErrorHandler { get; set; }
        public SocketAdapterOptions Options { get; set; }

        public SocketAdapter()
        {
            socket = new StreamSocket();
        }

        public SocketAdapter(StreamSocket socket)
        {
            this.socket = socket;
        }

        public IAsyncAction Connect(string host, int port)
        {
            return TaskConnect(host, port).AsAsyncAction();
        }

        public IAsyncAction Write(byte[] data)
        {
            return TaskWrite(data).AsAsyncAction();
        }

        public void ShutdownWrite()
        {
            socket.CancelIOAsync();
        }

        public void Close()
        {
            CloseEventHandler?.Invoke(false);
            socket.Dispose();
        }

        private async Task TaskConnect(string host, int port)
        {
            await socket.ConnectAsync(new HostName(host), port.ToString());

            await StartReadTask();
        }

        private async Task TaskWrite(byte[] data)
        {
            using (var outputStream = socket.OutputStream.AsStreamForWrite())
            {
                await outputStream.WriteAsync(data, 0, data.Length);
                await outputStream.FlushAsync();
            }
        }

        private Task StartReadTask()
        {
            return Task.Factory.StartNew(() => RunRead());
        }

        private async Task RunRead()
        {
            bool hasError = false;
            try
            {
                await RunReadLoop();
            }
            catch (Exception ex)
            {
                hasError = true;
                ErrorHandler?.Invoke(ex);
            }
            finally
            {
                socket.Dispose();
                CloseEventHandler?.Invoke(hasError);
            }
        }

        private async Task RunReadLoop()
        {
            byte[] buffer = new byte[InputStreamBufferSize];
            int bytesRead = 0;

            do
            {
                using (MemoryStream ms = new MemoryStream())
                {
                    var stream = socket.InputStream.AsStreamForRead();
                    bytesRead = await stream.ReadAsync(buffer, 0, InputStreamBufferSize);
                    byte[] data = new byte[bytesRead];
                    Array.Copy(buffer, data, data.Length);
                    DataConsumer?.Invoke(data);
                }
            }
            while (bytesRead != 0);
        }
    }
}
