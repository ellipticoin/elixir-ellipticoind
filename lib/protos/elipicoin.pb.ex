defmodule Elipticoin.FuncAndArgs do
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
    func:       String.t,
    args:       String.t,
    public_key: String.t,
    signature:  String.t
  }
  defstruct [:func, :args, :public_key, :signature]

  field :func, 1, type: :string
  field :args, 2, type: :bytes
  field :public_key, 3, type: :bytes
  field :signature, 4, type: :bytes
end

defmodule Elipticoin.ReturnData do
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
    bytes: String.t
  }
  defstruct [:bytes]

  field :bytes, 1, type: :bytes
end
