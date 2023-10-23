defmodule STT.Sentence.LanguageInfo do
  @type t :: %__MODULE__{
          word_delimiter: String.t(),
          writing_direction: writing_direction()
        }

  @type writing_direction :: :left_to_right | :right_to_left

  @default_word_delimiter " "
  @default_writing_direction :left_to_right

  defstruct word_delimiter: " ", writing_direction: :left_to_right

  def parse(map) do
    writing_direction =
      map
      |> Map.get("writing_direction")
      |> then(&(&1 && parse_writing_direction(&1))) ||
        @default_writing_direction

    %__MODULE__{
      word_delimiter: Map.get(map, "word_delimiter", @default_word_delimiter),
      writing_direction: writing_direction
    }
  end

  defp parse_writing_direction("left-to-right"), do: :left_to_right
  defp parse_writing_direction("right-to-left"), do: :right_to_left
end
