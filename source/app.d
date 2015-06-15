import std.range;
import std.socket;
import std.stdio;
import std.getopt;
import std.parallelism;

void check(string host, ushort begin = 1, ushort end = 1024, uint threads = 32) {
    bool[ushort] results;
    auto pool = new TaskPool(threads); 

    foreach (ushort port; pool.parallel(iota!(ushort, ushort)(begin, end))) {
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
            results[port] = false;
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

    stdout.flush();
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

void listen(string host, ushort begin = 1, ushort end = 1024) {
    foreach (ushort port; iota!(ushort, ushort)(begin, end)) {
        task!listenPort(host, port)
            .executeInNewThread();
    }
}

void main(string[] args)
{
    bool isServer = false;
    auto host = "0.0.0.0";
    ushort begin = 1;
    ushort end = 1024;
    uint threads = 32;

    args.getopt("server|s", &isServer, "host|h", &host, "begin|b", &begin, "end|e", &end, "threads|t", &threads);

    if (isServer) {
        listen(host, begin, end);
    } else {
        check(host, begin, end, threads);
    }
}
