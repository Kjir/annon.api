defmodule Annon.ManagementAPI.Controllers.APIPluginTest do
  @moduledoc false
  use Annon.ConnCase, async: true
  alias Annon.Factories.Configuration, as: ConfigurationFactory

  setup %{conn: conn} do
    conn =
      conn
      |> put_req_header("accept", "application/json")
      |> put_req_header("content-type", "application/json")

    %{
      conn: conn,
      api: ConfigurationFactory.insert(:api)
    }
  end

  describe "on index" do
    test "lists all plugins", %{conn: conn, api: api} do
      assert [] ==
        conn
        |> get(plugins_path(api.id))
        |> json_response(200)
        |> Map.get("data")

      plugin1_name = ConfigurationFactory.insert(:proxy_plugin, api_id: api.id).name
      plugin2_name = ConfigurationFactory.insert(:auth_plugin_with_jwt, api_id: api.id).name

      resp =
        conn
        |> get(plugins_path(api.id))
        |> json_response(200)
        |> Map.get("data")

      assert [%{"name" => resp_plugin1_name}, %{"name" => resp_plugin2_name}] = resp
      assert plugin1_name in [resp_plugin1_name, resp_plugin2_name]
      assert plugin2_name in [resp_plugin1_name, resp_plugin2_name]
    end
  end

  describe "on read" do
    test "returns 404 when plugin does not exist", %{conn: conn, api: api} do
      conn
      |> get(plugin_path(api.id, "proxy"))
      |> json_response(404)
    end

    test "returns 404 when plugin name is not known", %{conn: conn, api: api} do
      conn
      |> get(plugin_path(api.id, "unknown_plugin"))
      |> json_response(404)
    end

    test "returns plugin in valid structure", %{conn: conn, api: api} do
      plugin = ConfigurationFactory.insert(:proxy_plugin, api_id: api.id)

      resp =
        conn
        |> get(plugin_path(api.id, plugin.name))
        |> json_response(200)
        |> Map.get("data")

      assert resp["name"] == plugin.name
      assert resp["settings"] == plugin.settings
      assert resp["is_enabled"] == plugin.is_enabled
    end
  end

  describe "on create or update" do
    test "creates plugin when plugin does not exist", %{conn: conn, api: api} do
      create_attrs = ConfigurationFactory.params_for(:proxy_plugin, api_id: api.id)

      resp =
        conn
        |> put_json(plugin_path(api.id, create_attrs.name), %{"plugin" => create_attrs})
        |> json_response(201)
        |> Map.get("data")

      assert resp["name"] == create_attrs.name
      assert resp["api_id"] == create_attrs.api_id
      assert resp["settings"] == create_attrs.settings
      assert resp["is_enabled"] == create_attrs.is_enabled

      assert ^resp =
        conn
        |> get(plugin_path(api.id, create_attrs.name))
        |> json_response(200)
        |> Map.get("data")
    end

    test "updates plugin when it is exists", %{conn: conn, api: api} do
      plugin = ConfigurationFactory.insert(:proxy_plugin, api_id: api.id)
      update_overrides = [
        api_id: api.id,
        is_enabled: false,
        settings: %{
          "upstream" => %{
            "host" => "mydomain.com",
            "port" => 1234
          }
        }
      ]
      update_attrs = ConfigurationFactory.params_for(:proxy_plugin, update_overrides)

      resp =
        conn
        |> put_json(plugin_path(api.id, update_attrs.name), %{"plugin" => update_attrs})
        |> json_response(200)
        |> Map.get("data")

      assert DateTime.to_iso8601(plugin.inserted_at) == resp["inserted_at"]
      assert plugin.name == update_attrs.name
      assert update_attrs.api_id == resp["api_id"]
      assert update_attrs.is_enabled == resp["is_enabled"]
      assert update_attrs.settings["upstream"]["host"] == resp["settings"]["upstream"]["host"]
      assert update_attrs.settings["upstream"]["port"] == resp["settings"]["upstream"]["port"]

      assert ^resp =
        conn
        |> get(plugin_path(api.id, update_attrs.name))
        |> json_response(200)
        |> Map.get("data")
    end

    test "requires all fields to be present on update", %{conn: conn, api: api} do
      plugin = ConfigurationFactory.insert(:proxy_plugin, api_id: api.id)
      update_attrs = %{name: plugin.name}

      conn
      |> put_json(plugin_path(api.id, update_attrs.name), %{"plugin" => update_attrs})
      |> json_response(422)
    end

    test "uses name from path as plugin name", %{conn: conn, api: api} do
      create_attrs = ConfigurationFactory.params_for(:proxy_plugin, api_id: api.id, name: "other_plugin_name")

      resp =
        conn
        |> put_json(plugin_path(api.id, "proxy"), %{"plugin" => create_attrs})
        |> json_response(201)

      assert %{"data" => %{"name" => "proxy"}} = resp
    end

    test "returns not found error when api does not exist", %{conn: conn, api: api} do
      create_attrs = ConfigurationFactory.params_for(:proxy_plugin, api_id: api.id)

      resp =
        conn
        |> put_json(plugin_path(Ecto.UUID.generate(), create_attrs.name), %{"plugin" => create_attrs})
        |> json_response(404)

      assert %{"meta" => %{"code" => 404}} = resp
    end
  end

  describe "on delete" do
    test "returns not found error when api does not exist", %{conn: conn, api: api} do
      create_attrs = ConfigurationFactory.params_for(:proxy_plugin, api_id: api.id)

      resp =
        conn
        |> put_json(plugin_path(Ecto.UUID.generate(), create_attrs.name), %{"plugin" => create_attrs})
        |> json_response(404)

      assert %{"meta" => %{"code" => 404}} = resp
    end

    test "returns no content when plugin does not exist", %{conn: conn, api: api} do
      resp =
        conn
        |> delete(plugin_path(api.id, "proxy"))
        |> response(204)

      assert "" = resp
    end

    test "returns no content when plugin is deleted", %{conn: conn, api: api} do
      plugin = ConfigurationFactory.insert(:proxy_plugin, api_id: api.id)

      resp =
        conn
        |> delete(plugin_path(api.id, plugin.name))
        |> response(204)

      assert "" = resp

      conn
      |> get(plugin_path(api.id, plugin.name))
      |> json_response(404)
    end
  end
end
