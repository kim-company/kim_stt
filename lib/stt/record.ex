defmodule Membrane.STT.Record do
  @type t :: %__MODULE__{
          from: non_neg_integer(),
          to: non_neg_integer(),
          text: String.t(),
          type: String.t(),
          is_eos: boolean() | nil,
          speaker: String.t() | nil
        }
  defstruct [:from, :to, :text, :type, :is_eos, :speaker]
end
