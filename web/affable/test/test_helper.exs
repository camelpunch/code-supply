ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(Affable.Repo, :manual)
Hammox.defmock(Affable.MockK8s, for: Affable.K8s)
Hammox.defmock(Affable.MockSiteClusterIO, for: Affable.SiteClusterIO)
Hammox.defmock(Affable.MockBroadcaster, for: Affable.Broadcaster)
