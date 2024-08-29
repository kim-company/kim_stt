defmodule STT.Sentence.Builder do
  alias STT.Sentence
  alias STT.Sentence.LanguageInfo
  alias STT.Record

  @type t :: %__MODULE__{
          speaker: String.t() | :unidentified | nil,
          records: [Record.t()],
          language_info: LanguageInfo.t(),
          silence_split_threshold: number
        }

  @type word :: {:word | :punctuation, String.t()}

  defstruct [
    :speaker,
    :silence_split_threshold,
    records: [],
    language_info: %LanguageInfo{}
  ]

  @match_punctuation_splitter ~r/\w\w\w+[!?\.]$/
  @match_number ~r/\d/

  @doc """
  Adds records to the builder. If this records completes a sentence, it will return the sentence
  """
  @spec add_records(t(), Record.t() | [Record.t()]) :: {[Sentence.t()], t()}
  def add_records(%__MODULE__{} = builder, records, flush \\ false) do
    records = builder.records ++ List.wrap(records)
    {finals, partial} = split_records(records, builder.silence_split_threshold)
    sentences = build_sentence(finals, builder.language_info)
    builder = %__MODULE__{builder | records: partial}

    if not flush do
      {sentences, builder}
    else
      {rest, builder} = flush(builder)
      {sentences ++ rest, builder}
    end
  end

  @doc """
  Update the language info
  """
  @spec update_language_info(t(), LanguageInfo.t()) :: t()
  def update_language_info(builder, language_info) do
    %{builder | language_info: language_info}
  end

  @doc """
  Flushes the collected words into sentences. Can return partial sentences.
  """
  @spec flush(t()) :: {[Sentence.t()], t()}
  def flush(builder) do
    {finals, partial} = split_records(builder.records, builder.silence_split_threshold)

    {build_sentence(finals ++ [partial], builder.language_info),
     %__MODULE__{builder | records: []}}
  end

  @doc """
  Checks if there are any pending records within the builder
  """
  def empty?(builder), do: Enum.empty?(builder.records)

  defp build_sentence(chunks, language_info) do
    chunks
    |> Enum.reject(&Enum.empty?/1)
    |> Enum.map(fn words ->
      first = Enum.at(words, 0)

      %Sentence{
        words: words,
        language_info: language_info,
        speaker: first.speaker,
        from: first.from,
        to: Enum.at(words, -1).to
      }
    end)
  end

  defp split_records(records, silence_split_threshold) do
    # We use a different splittig strategy depending on the information
    # the records contain.
    with_eos? = Enum.any?(records, & &1.is_eos)
    chunk_function = &chunk_sentences(&1, &2, with_eos?, silence_split_threshold)

    {ready, [doing]} =
      records
      |> Enum.chunk_while([], chunk_function, fn acc -> {:cont, acc, []} end)
      |> Enum.split(-1)

    ready = Enum.map(ready, &Enum.reverse/1)
    doing = Enum.reverse(doing)
    last = List.last(doing)

    # Make sure that the last partial is not a pretty-ending one; if so,
    # make it a final.
    if last != nil and is_punctuation_splitter?(last.text) do
      {ready ++ [doing], []}
    else
      {ready, doing}
    end
  end

  defp chunk_sentences(record, acc, with_eos?, silence_split_threshold) do
    # Check if there is a split before the current record
    if should_split_head?([record | acc], with_eos?, silence_split_threshold),
      # We have encountered a split. Emit current chunk
      do: {:cont, acc, [record]},

      # No split. add to list
      else: {:cont, [record | acc]}
  end

  defp should_split_head?(records, with_eos, max_silence) do
    should_split_head_by_silence?(records, max_silence) or
      should_split_head_by_punctuation?(records, with_eos)
  end

  defp should_split_head_by_silence?([next, prev | _rest], max_silence) do
    next.from - prev.to > max_silence
  end

  defp should_split_head_by_silence?(_, _), do: false

  defp should_split_head_by_punctuation?([_next, prev | _], true) do
    prev.is_eos
  end

  defp should_split_head_by_punctuation?(_, true), do: false

  defp should_split_head_by_punctuation?([_next, next, prev | _], false) do
    next.type == "punctuation" and is_punctuation_splitter?(next.text) and
      not is_number?(prev.text)
  end

  defp should_split_head_by_punctuation?(_, false), do: false

  defp is_number?(text), do: Regex.match?(@match_number, text)

  defp is_punctuation_splitter?(text), do: Regex.match?(@match_punctuation_splitter, text)
end
