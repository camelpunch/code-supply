defmodule SiteOperator.PhoenixSites.PhoenixSite do
  @enforce_keys [:name, :image, :domains, :secret_key_base, :distribution_cookie]
  defstruct [:name, :image, :domains, :secret_key_base, :distribution_cookie]
end