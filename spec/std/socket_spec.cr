require "spec"
require "socket"

describe "Socket::IPAddr" do
  it "transforms an IPv4 address into a C struct and back again" do
    addr1 = Socket::IPAddr.new(Socket::Family::INET, "127.0.0.1", 8080.to_i16)
    addr2 = Socket::IPAddr.new(addr1.sockaddr, addr1.addrlen)

    addr1.family.should eq(addr2.family)
    addr1.port.should eq(addr2.port)
    addr1.address.should eq(addr2.address)
  end

  it "transforms an IPv6 address into a C struct and back again" do
    addr1 = Socket::IPAddr.new(Socket::Family::INET6, "2001:db8:8714:3a90::12", 8080.to_i16)
    addr2 = Socket::IPAddr.new(addr1.sockaddr, addr1.addrlen)

    addr1.family.should eq(addr2.family)
    addr1.port.should eq(addr2.port)
    addr1.address.should eq(addr2.address)
  end
end

describe "UNIXSocket" do
  it "sends and receives messages" do
    path = "/tmp/crystal-test-unix-sock"

    UNIXServer.open(path) do |server|
      server.addr.family.should eq(Socket::Family::UNIX)
      server.addr.path.should eq(path)

      UNIXSocket.open(path) do |client|
        client.addr.family.should eq(Socket::Family::UNIX)
        client.addr.path.should eq(path)

        server.accept do |sock|
          sock.sync?.should eq(server.sync?)

          sock.addr.family.should eq(Socket::Family::UNIX)
          sock.addr.path.should eq("")

          sock.peeraddr.family.should eq(Socket::Family::UNIX)
          sock.peeraddr.path.should eq("")

          client << "ping"
          sock.gets(4).should eq("ping")
          sock << "pong"
          client.gets(4).should eq("pong")
        end
      end

      # test sync flag propagation after accept
      server.sync = !server.sync?

      UNIXSocket.open(path) do |client|
        server.accept do |sock|
          sock.sync?.should eq(server.sync?)
        end
      end
    end
  end

  it "creates a pair of sockets" do
    UNIXSocket.pair do |left, right|
      left.addr.family.should eq(Socket::Family::UNIX)
      left.addr.path.should eq("")

      left << "ping"
      right.gets(4).should eq("ping")
      right << "pong"
      left.gets(4).should eq("pong")
    end
  end

  it "tests read and write timeouts" do
    UNIXSocket.pair do |left, right|
      # BUG: shrink the socket buffers first
      left.write_timeout = 0.0001
      right.read_timeout = 0.0001
      buf = ("a" * 4096).to_slice

      expect_raises(IO::Timeout, "write timed out") do
        loop { left.write buf }
      end

      expect_raises(IO::Timeout, "read timed out") do
        loop { right.read buf }
      end
    end
  end

  it "tests socket options" do
    UNIXSocket.pair do |left, right|
      size = 12000
      # linux returns size * 2
      sizes = [size, size * 2]

      (left.send_buffer_size = size).should eq(size)
      sizes.should contain(left.send_buffer_size)

      (left.recv_buffer_size = size).should eq(size)
      sizes.should contain(left.recv_buffer_size)
    end
  end

  it "creates the socket file" do
    path = "/tmp/crystal-test-unix-sock"

    UNIXServer.open(path) do
      File.exists?(path).should be_true
    end
  end
end

describe "TCPServer" do
  it "fails when port is in use" do
    expect_raises Errno, /(already|Address) in use/ do
      TCPServer.open("::", 0) do |server|
        TCPServer.open("::", server.addr.port) { }
      end
    end
  end
end

describe "TCPSocket" do
  it "sends and receives messages" do
    TCPServer.open("::", 12345) do |server|
      server.addr.family.should eq(Socket::Family::INET6)
      server.addr.port.should eq(12345)
      server.addr.address.should eq("::")

      # test protocol specific socket options
      server.reuse_address?.should be_true # defaults to true
      (server.reuse_address = false).should be_false
      server.reuse_address?.should be_false
      (server.reuse_address = true).should be_true
      server.reuse_address?.should be_true

      (server.keepalive = false).should be_false
      server.keepalive?.should be_false
      (server.keepalive = true).should be_true
      server.keepalive?.should be_true

      (server.linger = nil).should be_nil
      server.linger.should be_nil
      (server.linger = 42).should eq 42
      server.linger.should eq 42

      TCPSocket.open("::", server.addr.port) do |client|
        # The commented lines are actually dependent on the system configuration,
        # so for now we keep it commented. Once we can force the family
        # we can uncomment them.

        # client.addr.family.should eq(Socket::Family::INET)
        # client.addr.address.should eq("127.0.0.1")

        sock = server.accept
        sock.sync?.should eq(server.sync?)

        # sock.addr.family.should eq(Socket::Family::INET6)
        # sock.addr.port.should eq(12345)
        # sock.addr.address.should eq("::ffff:127.0.0.1")

        # sock.peeraddr.family.should eq(Socket::Family::INET6)
        # sock.peeraddr.address.should eq("::ffff:127.0.0.1")

        # test protocol specific socket options
        (client.tcp_nodelay = true).should be_true
        client.tcp_nodelay?.should be_true
        (client.tcp_nodelay = false).should be_false
        client.tcp_nodelay?.should be_false

        (client.tcp_keepalive_idle = 42).should eq 42
        client.tcp_keepalive_idle.should eq 42
        (client.tcp_keepalive_interval = 42).should eq 42
        client.tcp_keepalive_interval.should eq 42
        (client.tcp_keepalive_count = 42).should eq 42
        client.tcp_keepalive_count.should eq 42

        client << "ping"
        sock.gets(4).should eq("ping")
        sock << "pong"
        client.gets(4).should eq("pong")
      end

      # test sync flag propagation after accept
      server.sync = !server.sync?

      TCPSocket.open("localhost", server.addr.port) do |client|
        sock = server.accept
        sock.sync?.should eq(server.sync?)
      end
    end
  end

  it "fails when connection is refused" do
    port = 0
    TCPServer.open("localhost", port) do |server|
      port = server.addr.port
    end

    expect_raises(Errno, "Error connecting to 'localhost:#{port}': Connection refused") do
      TCPSocket.new("localhost", port)
    end
  end

  it "fails when host doesn't exist" do
    expect_raises(Socket::Error, /^getaddrinfo: (.+ not known|no address .+|Non-recoverable failure in name resolution|Name does not resolve)$/i) do
      TCPSocket.new("localhostttttt", 12345)
    end
  end
end

describe "UDPSocket" do
  it "sends and receives messages by reading and writing" do
    server = UDPSocket.new(Socket::Family::INET6)
    server.bind("::", 0)

    server.addr.family.should eq(Socket::Family::INET6)
    server.addr.port.should eq(12346)
    server.addr.address.should eq("::")

    client = UDPSocket.new(Socket::Family::INET)
    client.connect("127.0.0.1", 12346)

    client.addr.family.should eq(Socket::Family::INET)
    client.addr.address.should eq("127.0.0.1")
    client.peeraddr.family.should eq(Socket::Family::INET)
    client.peeraddr.port.should eq(12346)
    client.peeraddr.address.should eq("127.0.0.1")

    client << "message"
    server.gets(7).should eq("message")

    client.close
    server.close
  end

  it "sends and receives messages by sendto and recvfrom over IPv4" do
    server = UDPSocket.new(Socket::Family::INET)
    server.bind("127.0.0.1", 12347)

    client = UDPSocket.new(Socket::Family::INET)

    client.sendto("message equal to buffer".to_slice, server.addr)
    message1, addr1 = server.recvfrom(23)
    String.new(message1).should eq("message equal to buffer")
    addr1.family.should eq(server.addr.family)
    addr1.address.should eq(server.addr.address)

    client.sendto("message less than buffer".to_slice, server.addr)
    message2, addr2 = server.recvfrom(256)
    String.new(message2).should eq("message less than buffer")
    addr2.family.should eq(server.addr.family)
    addr2.address.should eq(server.addr.address)

    server.close
    client.close
  end

  it "sends and receives messages by sendto and recvfrom over IPv6" do
    server = UDPSocket.new(Socket::Family::INET6)
    server.bind("::1", 12348)

    client = UDPSocket.new(Socket::Family::INET6)

    client.sendto("message".to_slice, server.addr)
    message, addr = server.recvfrom(1500)
    String.new(message).should eq("message")
    addr.family.should eq(server.addr.family)
    addr.address.should eq(server.addr.address)

    server.close
    client.close
  end

  it "broadcast messages" do
    client = UDPSocket.new(Socket::Family::INET)
    client.broadcast = true
    client.broadcast?.should be_true
    client.connect("255.255.255.255", 12349)
    client.send("broadcast".to_slice).should eq(9)
    client.close
  end
end
