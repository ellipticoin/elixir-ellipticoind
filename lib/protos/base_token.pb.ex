defmodule Elipticoin.Empty do
  use Protobuf, syntax: :proto3

  defstruct []

end

defmodule Elipticoin.Address do
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
    bytes: String.t
  }
  defstruct [:bytes]

  field :bytes, 1, type: :bytes
end

defmodule Elipticoin.TransferArgs do
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
    receiver_address: String.t,
    amount:           non_neg_integer
  }
  defstruct [:receiver_address, :amount]

  field :receiver_address, 1, type: :bytes
  field :amount, 2, type: :uint64
end

defmodule Elipticoin.Balance do
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
    amount: non_neg_integer
  }
  defstruct [:amount]

  field :amount, 1, type: :uint64
end
