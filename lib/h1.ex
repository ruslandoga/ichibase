defmodule H1 do
  @moduledoc "A minimal HTTP/1.1 server"
  use GenServer
  require Logger

  def start_link(opts) do
    {gen_opts, opts} = Keyword.split(opts, [:name, :debug, :spawn_opt])
    GenServer.start_link(__MODULE__, opts, gen_opts)
  end

  @impl true
  def init(opts) do
    Process.flag(:trap_exit, true)
    handler = Keyword.fetch!(opts, :handler)

    unless is_function(handler, 1) do
      raise ArgumentError, "handler must be a function of arity 1, got: #{inspect(handler)}"
    end

    # TODO check file descriptor and port limits?
    # iex(2)> :erlang.system_info :port_limit
    # 65536
    # iex(3)> System.cmd("ulimit", ["-n"])
    # {"256\n", 0}

    ip = Keyword.get(opts, :ip, {127, 0, 0, 1})
    port = Keyword.get(opts, :port, 0)

    # TODO sndbuf, rcvbuf, sndbuf
    # TODO https://www.erlang.org/doc/apps/kernel/inet#setopts/2
    # TODO https://www.erlang.org/doc/apps/kernel/gen_tcp.html#t:option/0

    sockopts = [
      mode: :binary,
      ip: ip,
      backlog: 32768,
      active: false,
      reuseaddr: true,
      nodelay: true
    ]

    with {:ok, socket} <- :gen_tcp.listen(port, sockopts) do
      state = %{socket: socket, handler: handler}
      for _ <- 1..100, do: spawn_acceptor(state)
      {:ok, state}
    else
      {:error, reason} -> {:stop, reason}
    end
  end

  @impl true
  def handle_cast(:accepted, state) do
    spawn_acceptor(state)
    {:noreply, state}
  end

  @impl true
  def handle_info({:EXIT, pid, reason}, state) do
    case reason do
      :normal ->
        {:noreply, state}

      :emfile ->
        Logger.error("http server ran out of file descriptors, stopping")
        {:stop, reason, state}

      reason ->
        log = "http request #{inspect(pid)} terminating\n" <> format_exit(reason)
        Logger.error(log, crash_reason: reason)
        {:noreply, state}
    end
  end

  defp format_exit(reason) do
    case reason do
      {e, stack} when is_list(stack) -> Exception.format(:error, e, stack)
      _other -> Exception.format(:exit, reason)
    end
  end

  defp spawn_acceptor(%{socket: socket, handler: handler}) do
    :proc_lib.spawn_link(__MODULE__, :accept, [_parent = self(), socket, handler])
  end

  @doc false
  def accept(parent, listen_socket, handler) do
    case :gen_tcp.accept(listen_socket, :infinity) do
      {:ok, socket} ->
        GenServer.cast(parent, :accepted)
        handle_client(socket, _buffer = <<>>, handler)

      # TODO econnaborted? etc.
      # https://github.com/knutin/elli/blob/35eb9e8af459f48698bae7c6096d128e2f34fd6a/src/elli_http.erl#L39-L44

      {:error, _reason} ->
        exit(:normal)
    end
  end

  defp handle_client(socket, buffer, handler) do
    case handle_request(socket, buffer, handler) do
      :close -> shutdown_close(socket)
      buffer -> handle_client(socket, buffer, handler)
    end
  end

  defp handle_request(socket, buffer, handler) do
    {method, url, version, req_headers, buffer} = receive_request(socket, buffer)
    {body, buffer} = receive_body(socket, buffer, req_headers)

    req = %{
      method: method,
      url: url,
      version: version,
      headers: req_headers,
      body: body
    }

    {status, resp_headers, body} = handler.(req)
    :ok = :gen_tcp.send(socket, format_response(status, resp_headers, body))

    # TODO http/1.0
    case Map.get(req_headers, "connection") == "close" or
           Map.get(resp_headers, "connection") == "close" do
      true -> :close
      false -> buffer
    end
  end

  # TODO too aggressive?
  defp receive_request(socket, buffer) when byte_size(buffer) <= 10000 do
    case :erlang.decode_packet(:http_bin, buffer, []) do
      {:more, _} ->
        case :gen_tcp.recv(socket, 0, :timer.seconds(10)) do
          {:ok, data} -> receive_request(socket, buffer <> data)
          {:error, _reason} -> exit(:normal)
        end

      {:ok, {:http_request, method, raw_path, version}, buffer} ->
        {headers, buffer} = receive_headers(socket, version, buffer)
        {method, raw_path, version, headers, buffer}

      {:ok, {:http_error, _reason} = _error, _buffer} ->
        send_bad_request(socket)
        shutdown_close(socket)
        exit(:normal)

      {:ok, {:http_response, _, _, _}, _buffer} ->
        shutdown_close(socket)
        exit(:http_response_received)
    end
  end

  defp receive_request(socket, _buffer) do
    send_bad_request(socket)
    shutdown_close(socket)
    exit(:http_request_too_large)
  end

  # TODO
  defp receive_headers(socket, {0, 9}, _buffer) do
    send_bad_request(socket)
    shutdown_close(socket)
    exit(:http_version_not_supported)
  end

  defp receive_headers(socket, {1, _}, buffer) do
    receive_headers(socket, buffer, %{}, _hcount = 0, _hsize = 0)
  end

  # TODO too aggressive?
  defp receive_headers(socket, _buffer, _headers, hcount, hsize)
       when hcount > 100 or hsize > 10000 do
    send_bad_request(socket)
    shutdown_close(socket)
    exit(:http_header_too_large)
  end

  defp receive_headers(socket, buffer, headers, hcount, hsize) do
    case :erlang.decode_packet(:httph_bin, buffer, []) do
      {:ok, {:http_header, _, key, _, value}, rest} ->
        key = String.downcase(ensure_string(key))

        # TODO
        headers =
          Map.update(headers, key, value, fn
            prev when is_binary(prev) -> [prev, value]
            prev when is_list(prev) -> prev ++ [value]
          end)

        hcount = hcount + 1
        hsize = hsize + byte_size(buffer) - byte_size(rest)
        receive_headers(socket, rest, headers, hcount, hsize)

      {:ok, :http_eoh, rest} ->
        {headers, rest}

      {:ok, {:http_error, _}, rest} ->
        hsize = hsize + byte_size(buffer) - byte_size(rest)
        receive_headers(socket, rest, headers, hcount, hsize)

      {:more, _} ->
        case :gen_tcp.recv(socket, 0, :timer.seconds(10)) do
          {:ok, data} -> receive_headers(socket, buffer <> data, headers, hcount, hsize)
          # TODO timeout -> send_bad_request(socket)?
          {:error, _reason} -> exit(:normal)
        end
    end
  end

  defp ensure_string(key) when is_atom(key), do: Atom.to_string(key)
  defp ensure_string(key) when is_binary(key), do: key

  # TODO stream
  defp receive_body(socket, buffer, headers) do
    maybe_send_continue(socket, headers)

    case Map.get(headers, "content-length") do
      nil ->
        case Map.get(headers, "transfer-encoding") do
          "chunked" -> receive_chunked_body(socket, buffer, _bsize = 0)
          nil -> {nil, buffer}
        end

      content_length ->
        content_length = String.to_integer(content_length)
        receive_fixed_body(socket, buffer, content_length)
    end
  end

  defp receive_fixed_body(socket, buffer, content_length) when content_length < 1_000_000 do
    case content_length - byte_size(buffer) do
      0 ->
        {buffer, <<>>}

      n when n > 0 ->
        case :gen_tcp.recv(socket, n, :timer.seconds(30)) do
          {:ok, data} -> {buffer <> data, <<>>}
          # TODO timeout
          {:error, _reason} -> exit(:normal)
        end

      n when n < 0 ->
        <<body::size(content_length)-bytes, buffer::bytes>> = buffer
        {body, buffer}
    end
  end

  defp receive_fixed_body(socket, _buffer, _content_length) do
    :gen_tcp.send(socket, "HTTP/1.1 413 Request Entity Too Large\r\ncontent-length: 0\r\n\r\n")
    shutdown_close(socket)
    exit(:http_request_too_large)
  end

  # TODO
  defp receive_chunked_body(socket, _buffer, _bsize) do
    send_bad_request(socket)
    shutdown_close(socket)
    exit(:chunked_body_not_implemented)
  end

  defp maybe_send_continue(socket, headers) do
    case Map.get(headers, "expect") do
      "100-continue" ->
        :gen_tcp.send(socket, "HTTP/1.1 100 Continue\r\ncontent-length: 0\r\n\r\n")
        :ok

      _other ->
        :ok
    end
  end

  defp format_response(status, resp_headers, body) do
    [
      format_status_line(status),
      # TODO ensure date header
      format_headers(ensure_content_length(resp_headers, body)),
      "\r\n"
      | body
    ]
  end

  defp ensure_content_length(headers, body) do
    case Map.get(headers, "content-length") do
      nil -> Map.put(headers, "content-length", IO.iodata_length(body))
      _ -> headers
    end
  end

  defp format_headers(headers) do
    :maps.fold(&__MODULE__.format_header/3, [], headers)
  end

  @doc false
  def format_header(key, value, acc) do
    value =
      case value do
        _ when is_list(value) -> Enum.map_intersperse(value, ", ", &encode_value/1)
        _ -> encode_value(value)
      end

    [encode_value(key), ": ", value, "\r\n" | acc]
  end

  defp encode_value(i) when is_integer(i), do: Integer.to_string(i)
  defp encode_value(b) when is_binary(b), do: b

  defp shutdown_close(socket) do
    :gen_tcp.shutdown(socket, :write)
    :gen_tcp.close(socket)
  end

  defp send_bad_request(socket) do
    :gen_tcp.send(socket, "HTTP/1.1 400 Bad Request\r\ncontent-length: 11\r\n\r\nBad Request")
  end

  statuses = [
    {200, "200 OK"},
    {404, "404 Not Found"},
    {500, "500 Internal Server Error"},
    {400, "400 Bad Request"},
    {401, "401 Unauthorized"},
    {403, "403 Forbidden"},
    {429, "429 Too Many Requests"},
    {201, "201 Created"},
    # --------------------
    {100, "100 Continue"},
    {101, "101 Switching Protocols"},
    {102, "102 Processing"},
    {202, "202 Accepted"},
    {203, "203 Non-Authoritative Information"},
    {204, "204 No Content"},
    {205, "205 Reset Content"},
    {206, "206 Partial Content"},
    {207, "207 Multi-Status"},
    {226, "226 IM Used"},
    {300, "300 Multiple Choices"},
    {301, "301 Moved Permanently"},
    {302, "302 Found"},
    {303, "303 See Other"},
    {304, "304 Not Modified"},
    {305, "305 Use Proxy"},
    {306, "306 Switch Proxy"},
    {307, "307 Temporary Redirect"},
    {402, "402 Payment Required"},
    {405, "405 Method Not Allowed"},
    {406, "406 Not Acceptable"},
    {407, "407 Proxy Authentication Required"},
    {408, "408 Request Timeout"},
    {409, "409 Conflict"},
    {410, "410 Gone"},
    {411, "411 Length Required"},
    {412, "412 Precondition Failed"},
    {413, "413 Request Entity Too Large"},
    {414, "414 Request-URI Too Long"},
    {415, "415 Unsupported Media Type"},
    {416, "416 Requested Range Not Satisfiable"},
    {417, "417 Expectation Failed"},
    {418, "418 I'm a teapot"},
    {422, "422 Unprocessable Entity"},
    {423, "423 Locked"},
    {424, "424 Failed Dependency"},
    {425, "425 Unordered Collection"},
    {426, "426 Upgrade Required"},
    {428, "428 Precondition Required"},
    {431, "431 Request Header Fields Too Large"},
    {501, "501 Not Implemented"},
    {502, "502 Bad Gateway"},
    {503, "503 Service Unavailable"},
    {504, "504 Gateway Timeout"},
    {505, "505 HTTP Version Not Supported"},
    {506, "506 Variant Also Negotiates"},
    {507, "507 Insufficient Storage"},
    {510, "510 Not Extended"},
    {511, "511 Network Authentication Required"}
  ]

  for {code, status} <- statuses do
    def status(unquote(code)), do: unquote(status)
    defp format_status_line(unquote(code)), do: unquote("HTTP/1.1 " <> status <> "\r\n")
  end
end
