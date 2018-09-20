/*
  Copyright (c) 2015, Blocshop s.r.o.
  All rights reserved.

  Redistribution and use in source and binary forms are permitted
  provided that the above copyright notice and this paragraph are
  duplicated in all such forms and that any documentation,
  advertising materials, and other materials related to such
  distribution and use acknowledge that the software was developed
  by the Blocshop s.r.o.. The name of the
  Blocshop s.r.o. may not be used to endorse or promote products derived
  from this software without specific prior written permission.
  THIS SOFTWARE IS PROVIDED ``AS IS'' AND WITHOUT ANY EXPRESS OR
  IMPLIED WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED
  WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.
 */

package cz.blocshop.socketsforcordova;

import java.io.IOException;
import java.net.InetSocketAddress;
import java.net.ServerSocket;
import java.net.Socket;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;


public class ServerSocketAdapterImpl implements ServerSocketAdapter {
    private final ServerSocket serverSocket;
    private final ExecutorService executor;
    
    private Consumer<Void> startedEventHandler;
    private Consumer<String> startErrorEventHandler;
    private Consumer<SocketAdapter> openedEventHandler;
    private Consumer<Boolean> stoppedEventHandler;

    private boolean closeFlag = false;

    ServerSocketAdapterImpl() throws IOException {
        this.serverSocket = new ServerSocket();
        this.executor = Executors.newSingleThreadExecutor();
    }

    @Override
    public void start(final String iface, final int port) {
        this.executor.submit(new Runnable(){
            @Override
            public void run() {
                try {
                    serverSocket.bind(new InetSocketAddress(iface, port));
                    invokeStartedEventHandler();
                    submitAcceptTask();
                } catch (IOException e) {
                    Logging.Error(ServerSocketAdapterImpl.class.getName(), "Error during binding the socket", e.getCause());
                    invokeStartErrorEventHandler(e.getMessage());
                }
            }
        });
    }

    private void submitAcceptTask() {
        this.executor.submit(new Runnable(){
            @Override
            public void run() {
                boolean hasError = false;
            try {
                while (true) {
                    Socket socket = serverSocket.accept();
    
                    SocketAdapter socketAdapter = new SocketAdapterImpl(socket);
                    socketAdapter.submitReadTask();
    
                    invokeOpenedEventHandler(socketAdapter);
                }
            } catch (Throwable e) {
                if (!closeFlag) {
                    Logging.Error(ServerSocketAdapterImpl.class.getName(), "Caught during awaiting", e);
                    hasError = true;
                }
            } finally {
                try {
                    serverSocket.close();
                } catch (IOException e) {
                    Logging.Error(ServerSocketAdapterImpl.class.getName(), "Error during closing of socket", e);
                } finally {
                    invokeStoppedEventHandler(hasError);
                }
            }
            }
        });
    }
    
    @Override
    public void stop() {
        closeFlag = true;
    	try {
            serverSocket.close();
        } catch (IOException e) {
            Logging.Error(ServerSocketAdapterImpl.class.getName(), "Error during closing of socket", e);
        }
    }

    @Override
	public void setStartedEventHandler(Consumer<Void> startedEventHandler) {
		this.startedEventHandler = startedEventHandler;
	}

    private void invokeStartedEventHandler() {
        if (this.startedEventHandler != null) {
            this.startedEventHandler.accept(null);
        }
    }

    @Override
	public void setStartErrorEventHandler(Consumer<String> startErrorEventHandler) {
		this.startErrorEventHandler = startErrorEventHandler;
	}

    private void invokeStartErrorEventHandler(String error) {
        if (this.startErrorEventHandler != null) {
            this.startErrorEventHandler.accept(error);
        }
    }

	@Override
	public void setOpenedEventHandler(Consumer<SocketAdapter> openedEventHandler) {
		this.openedEventHandler = openedEventHandler;
	}

    private void invokeOpenedEventHandler(SocketAdapter socket) {
        if (this.openedEventHandler != null) {
            this.openedEventHandler.accept(socket);
        }
    }

    @Override
	public void setStoppedEventHandler(Consumer<Boolean> stoppedEventHandler) {
		this.stoppedEventHandler = stoppedEventHandler;
	}

    private void invokeStoppedEventHandler(boolean hasError) {
        if (this.stoppedEventHandler != null) {
            this.stoppedEventHandler.accept(hasError);
        }
    }
}
