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
using System.Linq;

namespace Blocshop.ScoketsForCordova
{
    internal interface ISocketStorage
    {
        void Add(string socketKey, ISocketAdapter socketAdapter);
        void AddServerSocket(string socketKey, ISocketServerAdapter socketServerAdapter);
        ISocketAdapter Get(string socketKey);
        ISocketServerAdapter GetServerSocket(string socketKey);
        void Remove(string socketKey);
    }

    internal sealed class SocketStorage : ISocketStorage
    {
        private readonly IDictionary<string, ISocketAdapter> socketAdapters = new Dictionary<string, ISocketAdapter>();
        private readonly IDictionary<string, ISocketServerAdapter> socketServerAdapters = new Dictionary<string, ISocketServerAdapter>();

        private object syncRoot = new object();

        public void Add(string socketKey, ISocketAdapter socketAdapter)
        {
            lock (syncRoot)
            {
                System.Diagnostics.Debug.WriteLine("Add: " + DateTime.Now.Ticks);
                socketAdapters.Add(socketKey, socketAdapter);
            }
        }

        public void AddServerSocket(string socketKey, ISocketServerAdapter socketAdapter)
        {
            lock (syncRoot)
            {
                System.Diagnostics.Debug.WriteLine("Add: " + DateTime.Now.Ticks);
                socketServerAdapters.Add(socketKey, socketAdapter);
            }
        }

        public ISocketAdapter Get(string socketKey)
        {
            lock (syncRoot)
            {
                System.Diagnostics.Debug.WriteLine("Get: " + DateTime.Now.Ticks);
                if (!socketAdapters.ContainsKey(socketKey))
                {
                    string key = "-";
                    if (socketAdapters.Count() > 0)
                        key = socketAdapters.First().Key;
                    throw new ArgumentException(
                        string.Format("Cannot find socketKey: {0}. Connection is probably closed. total sockets: {1}, first: {2}", socketKey, socketAdapters.Count(), key));
                }

                return socketAdapters[socketKey];
            }
        }

        public ISocketServerAdapter GetServerSocket(string socketKey)
        {
            lock (syncRoot)
            {
                System.Diagnostics.Debug.WriteLine("Get: " + DateTime.Now.Ticks);
                if (!socketServerAdapters.ContainsKey(socketKey))
                {
                    throw new ArgumentException(
                        string.Format("Cannot find socketServerKey: {0}. Connection is probably closed.", socketKey));
                }

                return socketServerAdapters[socketKey];
            }
        }

        public void Remove(string socketKey)
        {
            lock (syncRoot)
            {
                System.Diagnostics.Debug.WriteLine("Remove: " + DateTime.Now.Ticks);
                socketAdapters.Remove(socketKey);
            }
        }

        public static ISocketStorage CreateSocketStorage()
        {
            return new SocketStorage();
        }
    }
}
