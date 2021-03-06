defmodule Affable.Uploads.UploadRequest do
  @enforce_keys [
    :algorithm,
    :bucket_name,
    :key,
    :access_key_id,
    :google_service_account_json,
    :now
  ]
  defstruct @enforce_keys
end
