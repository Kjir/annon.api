defmodule Annon.ManagementAPI.Render do
  @moduledoc """
  Use this helpers when you want to render result in a controllers.
  """
  import Annon.Helpers.Response

  @doc """
  This render should be used for `Repo.all` results.
  """
  def render_collection(nil, conn) do
    send_error(conn, :not_found)
  end

  def render_collection({resources, %Ecto.Paging{} = paging}, conn) do
    conn = Plug.Conn.assign(conn, :paging, paging)
    render_collection(resources, conn)
  end

  def render_collection(resources, conn) when is_list(resources) do
    send(resources, conn, 200)
  end

  @doc """
  This render should be used for `Repo.one` results.
  """
  def render_schema(nil, conn),
    do: render_schema({:error, :not_found}, conn)
  def render_schema({:error, :not_found}, conn) do
    send_error(conn, :not_found)
  end

  def render_schema(resource, conn) when is_map(resource),
    do: render_schema({:ok, resource}, conn)
  def render_schema({:ok, resource}, conn) when is_map(resource) do
    send(resource, conn, 200)
  end

  @doc """
  This render should be used for `Repo.create` and `Repo.update` results.
  """
  def render_change(tuple, conn, status \\ 200)

  def render_change(nil, conn, _status) do
    send_error(conn, :not_found)
  end

  def render_change({:error, changeset}, conn, _status) do
    "422.json"
    |> EView.Views.ValidationError.render(%{changeset: changeset})
    |> send(conn, 422)
  end

  def render_change({:ok, resource}, conn, status) when is_map(resource) do
    send(resource, conn, status)
  end

  @doc """
  This render should be used for `Repo.delete_all` results.

  It will throw an error if you tried to delete more than one record in a DB.
  """
  def render_delete({0, _}, conn) do
    send_error(conn, :not_found)
  end

  def render_delete({1, _}, conn) do
    send(%{}, conn, 200)
  end

  def render_delete(conn) do
    Annon.Helpers.Response.send(conn, :no_content)
  end
end
