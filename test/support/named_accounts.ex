defmodule NamedAccounts do
  defmacro __using__(_) do
    quote do
      @alices_private_key "p4fmhRFGhGMDYXHKrzmh/nDHd8LqX4oBi6Frih91/fAvYzenSQKZ2Ttc+mUTcS/IPZr92EHhKcwsshyUw0w5Wg=="
                          |> Base.decode64!()

      @alice @alices_private_key
             |> Crypto.private_key_to_public_key()

      @bobs_private_key "FbJ84KTznL4ME5InsxJalt5Asv5tVTRJwGnkZTMXMLe9Ayfcm9LcBMhO15D6A5h+5VKfZu64Af7h7w1j8K+3AA=="
                        |> Base.decode64!()

      @bob @bobs_private_key
           |> Crypto.private_key_to_public_key()
    end
  end
end
