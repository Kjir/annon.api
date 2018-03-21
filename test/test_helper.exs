# Start mock server
{:ok, _} = Plug.Adapters.Cowboy2.http Annon.MockServer, [], port: Confex.get_env(:annon_api, :acceptance)[:mock][:port]

# Start Factory service
{:ok, _} = Application.ensure_all_started(:ex_machina)

# Switch SQL sandbox to manual mode
Ecto.Adapters.SQL.Sandbox.mode(Annon.Configuration.Repo, :manual)
Ecto.Adapters.SQL.Sandbox.mode(Annon.Requests.Repo, :manual)

# Start tests
ExUnit.start(exclude: [:pending])
