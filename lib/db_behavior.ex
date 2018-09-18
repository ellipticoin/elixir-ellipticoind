defmodule DbBehaviour do
  @callback reset() :: none
  @callback set_binary(any, any) :: none
  @callback set_map(any, any) :: none
  @callback get_binary(any) :: any
  @callback get_list(any) :: any
  @callback push(any, any) :: none
  @callback pop(any) :: any
end
