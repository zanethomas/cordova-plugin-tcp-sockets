using System;
using System.Linq;
using System.Threading.Tasks;
using Windows.Networking.Sockets;
using static Blocshop.ScoketsForCordova.SocketPlugin;

namespace Blocshop.ScoketsForCordova
{
    internal interface ISocketServerAdapter
    {
        Task Start(String iface, int port);
        Task Stop();
        Action<String> OpenedEventHandler { get; set; }
        Action<Boolean> StoppedEventHandler { get; set; }
    }

    internal class SocketServerAdapter : ISocketServerAdapter
    {
        public Action<String> OpenedEventHandler { get; set; }
        public Action<Boolean> StoppedEventHandler { get; set; }
        public StreamSocketListener streamSocketListener;

        private readonly ISocketStorage socketStorage;
        private readonly DataConsumeDelegate dataConsumeDelegate;
        private readonly CloseEventDelegate closeEventDelegate;
        private readonly ErrorDelegate errorDelegate;

        public SocketServerAdapter(
            ISocketStorage socketStorage,
            DataConsumeDelegate dataConsumeDelegate,
            CloseEventDelegate closeEventDelegate,
            ErrorDelegate errorDelegate)
        {
            this.socketStorage = socketStorage;
            this.dataConsumeDelegate = dataConsumeDelegate;
            this.closeEventDelegate = closeEventDelegate;
            this.errorDelegate = errorDelegate;
        }

        public async Task Start(string iface, int port)
        {
            try
            {
                streamSocketListener = new StreamSocketListener();
                streamSocketListener.ConnectionReceived += StreamSocketListener_ConnectionReceived;
                await streamSocketListener.BindEndpointAsync(new Windows.Networking.HostName(iface), port.ToString());
            }
            catch (Exception ex)
            {
                throw ex;
            }
        }

        public async Task Stop()
        {
            await streamSocketListener.CancelIOAsync();
            streamSocketListener.Dispose();
            StoppedEventHandler?.Invoke(false);
        }

        private async void StreamSocketListener_ConnectionReceived(StreamSocketListener sender, StreamSocketListenerConnectionReceivedEventArgs args)
        {
            try
            {
                //ISocketAdapter socket = new SocketAdapter(args.Socket);

                //var socketKey = Guid.NewGuid().ToString();
                //socket.DataConsumer = async (data) => await dataConsumeDelegate(socketKey, data.ToArray());
                //socket.CloseEventHandler = async (hasError) => await closeEventDelegate(socketKey, hasError);
                //socket.ErrorHandler = async (ex) => await errorDelegate(socketKey, ex);
                //socketStorage.Add(socketKey, socket);
                //await socket.StartReadTask();
                //OpenedEventHandler?.Invoke(socketKey);
            }
            catch (Exception)
            {
                return;
            }
        }
    }
}
