import std.range;
import std.socket;
import std.stdio;
import std.getopt;
import std.parallelism;

void check(string host) {
    bool[1024] results;
    auto pool = new TaskPool(32); 

    foreach (ushort port; pool.parallel(iota!(ushort, ushort)(1u, 1024u))) {
        auto socket = new TcpSocket;

        socket.setOption(SocketOptionLevel.SOCKET, SocketOption.SNDTIMEO, dur!"msecs"(500));
        socket.setOption(SocketOptionLevel.SOCKET, SocketOption.RCVTIMEO, dur!"msecs"(500));

        writeln(host, ':', port, ": Connecting...");

        try {
            socket.connect(new InternetAddress(host, port));

            results[port] = true;
            writeln(host, ':', port, ": SUCCEEDED");

            socket.close();
        } catch (Throwable t) {
            writeln(host, ':', port, ": FAILED");
        }
    }

    write("Succeeded: ");
    foreach (port, result; results) {
        if (result) write(port, ' ');
    }
    writeln();

    write("Failed: ");
    foreach (port, result; results) {
        if (!result) write(port, ' ');
    }
    writeln();
}

void listenPort(string host, ushort port) {
    try {
        auto listener = new TcpSocket;

        listener.setOption(SocketOptionLevel.SOCKET, SocketOption.REUSEADDR, true);
        listener.setOption(SocketOptionLevel.SOCKET, SocketOption.SNDTIMEO, dur!"msecs"(500));
        listener.setOption(SocketOptionLevel.SOCKET, SocketOption.RCVTIMEO, dur!"msecs"(500));

        listener.bind(new InternetAddress(host, port));
        listener.listen(1);

        writeln("Listening on ", port);

        while (1) {
            try {
                auto client = listener.accept();

                writeln("Connected on ", port, " from ", client.remoteAddress);

                client.close();
            } catch (Throwable t) {
            }
        }
    } catch (Throwable t) {
        writeln("Failed to listen on ", port, " (", t.msg, ')');
    }
}

void listen(string host) {
    foreach (ushort port; iota!(ushort, ushort)(1u, 1024u)) {
        task!listenPort(host, port)
            .executeInNewThread();
    }
}

void main(string[] args)
{
    bool isServer = false;
    auto host = "0.0.0.0";

    args.getopt("server|s", &isServer, "host|h", &host);

    if (isServer) {
        listen(host);
    } else {
        check(host);
    }
}
