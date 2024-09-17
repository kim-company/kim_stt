defmodule STT.Sentence do
  alias STT.Record
  alias STT.Sentence.LanguageInfo

  @type t :: %__MODULE__{
          words: [Record.t()],
          language_info: LanguageInfo.t()
        }
  defstruct [:words, language_info: %LanguageInfo{}]

  def duration(%{words: words}) when length(words) > 0 do
    first = List.first(words)
    last = List.last(words)
    last.to - first.from
  end

  def speakers(%{works: words}) do
    words
    |> Enum.map(fn x -> Map.get(x, :speaker) end)
    |> Enum.uniq()
  end

  defimpl String.Chars do
    defp remove_leading_punctuation(string) do
      Regex.replace(~r/^[\W\s]+/, string, "")
    end

    def to_string(sentence) do
      sentence.words
      |> Enum.filter(fn %{type: type} -> type != "silence" end)
      |> Enum.scan(nil, fn
        %{type: "punctuation"} = record, _ -> record.text
        record, nil -> record.text
        record, _ -> [sentence.language_info.word_delimiter, record.text]
      end)
      |> List.to_string()
      |> remove_leading_punctuation()
    end
  end
end
