defmodule Gateway.Plugins.Proxy do
  @moduledoc """
  [Proxy](http://docs.annon.apiary.io/#reference/plugins/proxy) - is a core plugin that
  sends incoming request to an upstream back-ends.
  """
  use Gateway.Helpers.Plugin,
    plugin_name: "proxy"

  import Gateway.Helpers.IP

  alias Plug.Conn
  alias Gateway.DB.Schemas.Plugin
  alias Gateway.DB.Schemas.API, as: APISchema

  @doc false
  def call(%Conn{private: %{api_config: %APISchema{plugins: plugins, request: %{path: api_path}}}} = conn, _opts)
    when is_list(plugins) do
    plugins
    |> find_plugin_settings()
    |> execute(api_path, conn)
  end
  def call(conn, _), do: conn

  defp execute(nil, _, conn), do: conn
  defp execute(%Plugin{settings: settings} = plugin, api_path, conn) do
    conn = plugin
    |> get_additional_headers()
    |> add_additional_headers(conn)
    |> skip_filtered_headers(settings)

    settings
    # TODO: check variables
    |> do_proxy(api_path, conn)
  end

  defp do_proxy(settings, api_path, %Conn{method: method} = conn) do
    response = settings
    |> make_link(api_path, conn)
    |> do_request(conn, method)
    |> get_response

    # TODO: Proxy response headers
    conn
    |> Conn.send_resp(response.status_code, response.body)
    |> Conn.halt
  end

  def do_request(link, conn, method) do
    body = conn
    |> Map.get(:body_params)
    |> Poison.encode!()

    method
    |> String.to_atom
    |> HTTPoison.request!(link, body, Map.get(conn, :req_headers))
    |> get_response
  end

  def get_response(%HTTPoison.Response{} = response), do: response

  def make_link(proxy, api_path, conn) do
    proxy
    |> put_scheme(conn)
    |> put_host(proxy)
    |> put_port(proxy)
    |> put_path(proxy, api_path, conn)
    |> put_query(proxy, conn)
  end

  def add_additional_headers(headers, conn) do
    headers
    |> Kernel.++([%{"x-forwarded-for" => ip_to_string(conn.remote_ip)}])
    |> Enum.reduce(conn, fn(header, conn) ->
      with {k, v} <- header |> Enum.at(0), do: Conn.put_req_header(conn, k, v)
    end)
  end

  defp get_additional_headers(%Plugin{settings: %{"additional_headers" => headers}}), do: headers
  defp get_additional_headers(_), do: []

  def skip_filtered_headers(conn, %{"strip_headers" => true, "headers_to_strip" => headers}) do
    Enum.reduce(headers, conn, &Plug.Conn.delete_req_header(&2, &1))
  end
  def skip_filtered_headers(conn, _plugin), do: conn

  defp put_scheme(%{"scheme" => scheme}, _conn), do: scheme <> "://"
  defp put_scheme(_, %Conn{scheme: scheme}), do: Atom.to_string(scheme) <> "://"

  defp put_host(pr, %{"host" => host}), do: pr <> host
  defp put_host(pr, %{}), do: pr

  defp put_port(pr, %{"port" => port}) when is_number(port), do: pr |> put_port(%{"port" => Integer.to_string(port)})
  defp put_port(pr, %{"port" => port}), do: pr <> ":" <> port
  defp put_port(pr, %{}), do: pr

  defp put_path(pr, %{"strip_request_path" => true, "path" => "/"}, api_path, %Conn{request_path: request_path}),
    do: pr <> String.trim_leading(request_path, api_path)

  defp put_path(pr, %{"strip_request_path" => true, "path" => proxy_path}, api_path, %Conn{request_path: request_path}),
    do: pr <> proxy_path <> String.trim_leading(request_path, api_path)

  defp put_path(pr, %{"strip_request_path" => true}, api_path, %Conn{request_path: request_path}),
    do: pr <> String.trim_leading(request_path, api_path)

  defp put_path(pr, %{"path" => "/"}, _api_path, %Conn{request_path: request_path}),
    do: pr <> request_path

  defp put_path(pr, %{"path" => proxy_path}, _api_path, %Conn{request_path: request_path}),
    do: pr <> proxy_path <> request_path

  defp put_path(pr, _proxy_path, _api_path, %Conn{request_path: request_path}),
    do: pr <> request_path

  defp put_query(pr, _, %Conn{query_string: ""}), do: pr
  defp put_query(pr, _, %Conn{query_string: query_string}), do: pr <> "?" <> query_string
end
