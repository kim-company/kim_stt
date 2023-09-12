defmodule STT.Record do
  @type t :: %__MODULE__{
          from: STT.Time.t(),
          to: STT.Time.t(),
          text: String.t(),
          type: String.t(),
          is_eos: boolean() | nil,
          speaker: String.t() | nil
        }
  defstruct [:from, :to, :text, :type, :is_eos, :speaker]
end
