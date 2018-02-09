defmodule BlacksmithService.Transfer do
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
    from:      String.t,
    to:        String.t,
    value:     non_neg_integer,
    nonce:     non_neg_integer,
    signature: String.t
  }
  defstruct [:from, :to, :value, :nonce, :signature]

  field :from, 1, type: :bytes
  field :to, 2, type: :bytes
  field :value, 3, type: :uint64
  field :nonce, 4, type: :uint64
  field :signature, 5, type: :bytes
end

defmodule BlacksmithService.Block do
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
    number:    non_neg_integer,
    transfers: [BlacksmithService.Transfer.t]
  }
  defstruct [:number, :transfers]

  field :number, 1, type: :uint64
  field :transfers, 2, repeated: true, type: BlacksmithService.Transfer
end

defmodule BlacksmithService.TransferResponse do
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
    transactionHash: String.t
  }
  defstruct [:transactionHash]

  field :transactionHash, 1, type: :bytes
end

defmodule BlacksmithService.Signable do
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
    from:      String.t,
    to:        String.t,
    value:     integer,
    nonce:     integer,
    signature: String.t
  }
  defstruct [:from, :to, :value, :nonce, :signature]

  field :from, 1, type: :bytes
  field :to, 2, type: :bytes
  field :value, 3, type: :int64
  field :nonce, 4, type: :int64
  field :signature, 5, type: :bytes
end

defmodule BlacksmithService.Empty do
  use Protobuf, syntax: :proto3

  defstruct []

end

defmodule BlacksmithService.Status do
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
    success:       boolean,
    error_message: String.t
  }
  defstruct [:success, :error_message]

  field :success, 1, type: :bool
  field :error_message, 2, type: :string
end

defmodule BlacksmithService.BalanceRequest do
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
    address: String.t
  }
  defstruct [:address]

  field :address, 1, type: :bytes
end

defmodule BlacksmithService.BalanceResponse do
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
    balance: non_neg_integer,
    success: boolean
  }
  defstruct [:balance, :success]

  field :balance, 1, type: :uint64
  field :success, 2, type: :bool
end

defmodule BlacksmithService.BlacksmithService.Service do
  use GRPC.Service, name: "blacksmith_service.BlacksmithService"

  rpc :GetBlockStream, BlacksmithService.Empty, stream(BlacksmithService.Block)
  rpc :GetBalance, BlacksmithService.BalanceRequest, BlacksmithService.BalanceResponse
  rpc :CreateTransfer, BlacksmithService.Transfer, stream(BlacksmithService.TransferResponse)
end

defmodule BlacksmithService.BlacksmithService.Stub do
  use GRPC.Stub, service: BlacksmithService.BlacksmithService.Service
end
