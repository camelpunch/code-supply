defmodule AffiliateWeb.PageLive do
  use AffiliateWeb, :live_view

  alias Affiliate.SiteState

  @impl true
  def mount(_params, _session, socket) do
    {pubsub, topic} = SiteState.subscription_info()
    %{"name" => _} = site = SiteState.site()
    Phoenix.PubSub.subscribe(pubsub, topic)
    {:ok, assign(socket, site: site, page_title: site["name"])}
  end

  @impl true
  def handle_info(site, socket) do
    {:noreply, assign(socket, site: site, page_title: site["name"])}
  end
end
