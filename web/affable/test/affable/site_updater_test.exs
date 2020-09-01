defmodule Affable.SiteUpdaterTest do
  use ExUnit.Case
  import Hammox

  alias Phoenix.PubSub
  alias Affable.MockRawSiteRetriever
  alias Affable.SiteUpdater

  setup :set_mox_from_context
  setup :verify_on_exit!

  setup do
    site_id = 1_234_567
    site_name = Affable.ID.site_name_from_id(site_id)

    PubSub.subscribe(:affable, site_name)

    server =
      start_supervised!({
        SiteUpdater,
        {MockRawSiteRetriever, :affable, "testsiteupdater"}
      })

    %{server: server, site_id: site_id, site_name: site_name}
  end

  test "responds to requests for content with a broadcast back for the site", %{
    site_id: site_id,
    site_name: site_name
  } do
    stub(MockRawSiteRetriever, :get_raw_site, fn ^site_id ->
      {:ok, %{name: "Some Site"}}
    end)

    :ok = PubSub.broadcast(:affable, "testsiteupdater", site_name)

    assert_receive %{name: "Some Site"}
  end

  test "can broadcast on demand", %{site_id: site_id} do
    SiteUpdater.broadcast(%{name: "Some Site", id: site_id})

    assert_receive %{name: "Some Site"}
  end
end
