defmodule Affable.SiteUpdaterTest do
  use Affable.DataCase, async: true

  import Hammox
  import Affable.SitesFixtures

  alias Affable.MockHTTP
  alias Affable.{Broadcaster, SiteUpdater}

  setup :verify_on_exit!

  setup_all do
    Hammox.protect(SiteUpdater, Broadcaster)
  end

  test "can broadcast full site on demand", %{broadcast_1: broadcast} do
    site = %{site_fixture() | id: 1}
    expected_name = site.name

    expected_url = "http://#{site.internal_hostname}/"

    expect(MockHTTP, :put, fn message, ^expected_url ->
      assert %{
               preview: %{"name" => ^expected_name},
               published: %{"name" => ^expected_name}
             } = message

      message
      |> put_in([:preview, "id"], 1)
      |> put_in([:published, "id"], 1)
      |> write_fixture_for_external_consumption("site_update_message")

      {:ok, %{}}
    end)

    assert broadcast.(site) == :ok
  end

  defp write_fixture_for_external_consumption(obj, name) do
    (Path.dirname(__ENV__.file) <> "/../../../fixtures/#{name}.ex")
    |> File.write!(
      inspect(
        for {key, val} <- obj, into: %{} do
          {Atom.to_string(key), val}
        end,
        pretty: true
      )
    )
  end
end
