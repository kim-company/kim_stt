defmodule STT.Sentence do
  alias STT.Record
  alias STT.Sentence.LanguageInfo

  @type t :: %__MODULE__{
          words: [Record.t()],
          from: pos_integer(),
          to: pos_integer(),
          speaker: String.t(),
          language_info: LanguageInfo.t()
        }
  defstruct [:words, :from, :to, :speaker, language_info: %LanguageInfo{}]

  defimpl String.Chars do
    def to_string(sentence) do
      Enum.scan(sentence.words, nil, fn
        %{type: "punctuation"} = record, _ -> record.text
        record, nil -> record.text
        record, _ -> [sentence.language_info.word_delimiter, record.text]
      end)
      |> List.to_string()
    end
  end
end
