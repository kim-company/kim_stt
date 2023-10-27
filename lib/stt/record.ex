defmodule STT.Record do
  @type t :: %__MODULE__{
          from: pos_integer(),
          to: pos_integer(),
          text: String.t(),
          type: String.t(),
          is_eos: boolean() | nil,
          speaker: String.t() | nil
        }
  defstruct [:from, :to, :text, :type, :is_eos, :speaker]
end
