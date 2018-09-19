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


namespace Blocshop.ScoketsForCordova
{
    public sealed class CloseSocketEvent
    {
        public string Type
        {
            get
            {
                return "Close";
            }
            set
            {
            }
        }

        public bool HasError { get; set; }

        public string SocketKey { get; set; }
    }

    public sealed class DataReceivedSocketEvent
    {
        public string Type
        {
            get
            {
                return "DataReceived";
            }
            set
            {
            }
        }

        public byte[] Data { get; set; }

        public string SocketKey { get; set; }
    }

    public sealed class ErrorSocketEvent
    {
        public string Type
        {
            get
            {
                return "Error";
            }
            set
            {
            }
        }

        public string ErrorMessage { get; set; }

        public string SocketKey { get; set; }
    }
}
