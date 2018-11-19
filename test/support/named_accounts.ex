defmodule NamedAccounts do
  defmacro __using__(_) do
    quote do
      @alice "509c3480af8118842da87369eb616eb7b158724927c212b676c41ce6430d334a"
             |> Base.decode16!(case: :lower)
      @alices_private_key "01a596e2624497da63a15ef7dbe31f5ca2ebba5bed3d30f3319ef22c481022fd509c3480af8118842da87369eb616eb7b158724927c212b676c41ce6430d334a"
                          |> Base.decode16!(case: :lower)
      @bob "027da28b6a46ec1124e7c3c33677b71f4ac4eae2485ff8cb33346aac54c11a30"
           |> Base.decode16!(case: :lower)
      @alices_private_key "01a596e2624497da63a15ef7dbe31f5ca2ebba5bed3d30f3319ef22c481022fd509c3480af8118842da87369eb616eb7b158724927c212b676c41ce6430d334a"
                          |> Base.decode16!(case: :lower)
      @alices_ethereum_private_key Application.fetch_env!(:blacksmith, :alices_ethereum_private_key)
      @bobs_ethereum_private_key Application.fetch_env!(:blacksmith, :bobs_ethereum_private_key)
      @carols_ethereum_private_key Application.fetch_env!(:blacksmith, :carols_ethereum_private_key)

      @alices_ethereum_account ExW3.accounts() |> Enum.at(0)
      @bobs_ethereum_account ExW3.accounts() |> Enum.at(0)
      @carols_ethereum_account ExW3.accounts() |> Enum.at(0)
    end
  end
end
