defmodule STT.Sentence.Builder do
  alias STT.Sentence
  alias STT.Sentence.LanguageInfo
  alias STT.Record

  @type sbd_mode :: :eos | :punctuation

  @type t :: %__MODULE__{
          pending: [Record.t()],
          mode: sbd_mode(),
          language_info: LanguageInfo.t()
        }

  @type word :: {:word | :punctuation, String.t()}

  defstruct pending: [],
            # Splitting mode. If the records contain eos information, it should
            # be the preferred one. Otherwise use :puntuation.
            mode: :eos,
            # Information about the language, used to build sentences. Provides
            # for example the word separator, which in most of the cases is " ".
            language_info: %LanguageInfo{}

  @doc """
  Adds records to the builder. If this records completes a sentence, it will return the sentence
  """
  @spec put_and_get(Record.t() | [Record.t()], t(), boolean()) :: {[Sentence.t()], t()}
  def put_and_get(records, builder, flush \\ false) do
    records
    |> put(builder)
    |> get(flush)
  end

  def put(records, builder) do
    records = builder.pending ++ List.wrap(records)
    records = fix_leading_punctuation(records)
    %__MODULE__{builder | pending: records}
  end

  def get(builder, flush \\ false) do
    {finals, partial} = split(builder.pending, builder.mode)
    sentences = build_sentences(finals, builder.language_info)
    builder = %__MODULE__{builder | pending: partial}

    if flush do
      {rest, builder} = flush(builder)
      {sentences ++ rest, builder}
    else
      {sentences, builder}
    end
  end

  def pending_sentences(builder) do
    build_sentences(builder.pending, builder.language_info)
  end

  @doc """
  Update the language info
  """
  @spec update_language_info(t(), LanguageInfo.t()) :: t()
  def update_language_info(builder, language_info) do
    %{builder | language_info: language_info}
  end

  @doc """
  Empties the builder returning all of its sentences. Last sentence might be a
  partial one.
  """
  @spec flush(t()) :: {[Sentence.t()], t()}
  def flush(builder) do
    {finals, partial} = split(builder.pending, builder.mode)

    {build_sentences(finals ++ [partial], builder.language_info),
     %__MODULE__{builder | pending: []}}
  end

  @doc """
  Checks if there are any pending records within the builder
  """
  def empty?(builder), do: Enum.empty?(builder.pending)

  defp build_sentences(chunks, language_info) do
    chunks
    |> Enum.reject(&Enum.empty?/1)
    |> Enum.flat_map(fn chunk ->
      {pre_silence, during} = Enum.split_while(chunk, fn x -> x.type == "silence" end)

      {post_silence_reversed, during_reversed} =
        during
        |> Enum.reverse()
        |> Enum.split_while(fn x -> x.type == "silence" end)

      batch = [pre_silence, Enum.reverse(during_reversed), Enum.reverse(post_silence_reversed)]
      Enum.filter(batch, fn x -> x != [] end)
    end)
    |> Enum.map(fn words ->
      match =
        words
        |> Enum.group_by(fn w -> w.language_code end)
        |> Enum.map(fn {code, x} -> {Enum.count(x), code} end)
        |> Enum.sort(:desc)
        |> List.first()

      language_code = case match do
        {_, x} -> x
        nil -> ""
      end

      %Sentence{
        words: words,
        language_code: language_code,
        language_info: language_info
      }
    end)
  end

  defp record_splitting_score(%{type: "punctuation", text: text})
       when text in [".", "!", "?", ";"],
       do: 9

  defp record_splitting_score(%{type: "punctuation"}), do: 2
  # defp record_splitting_score(%{type: "silence"}), do: 1
  defp record_splitting_score(_), do: 0

  defp split_chunked(records, splitter_fun) do
    {ready, [doing]} =
      records
      |> Enum.chunk_while(
        [],
        fn x, acc ->
          if splitter_fun.(x) do
            {:cont, [x | acc], []}
          else
            {:cont, [x | acc]}
          end
        end,
        fn acc ->
          # Emit also the last part as a chunk.
          {:cont, acc, []}
        end
      )
      |> Enum.map(&Enum.reverse/1)
      |> Enum.split(-1)

    {ready, doing}
  end

  defp split(records, _) when length(records) <= 1 do
    {[], records}
  end

  defp split(records, :eos) do
    split_chunked(records, fn x -> x.is_eos and x.text != "" end)
  end

  defp split(records, :punctuation) do
    records_with_score = Enum.map(records, fn x -> {x, record_splitting_score(x)} end)

    # We're only splitting the words based on the maximum splitting
    # score available.
    max_score =
      records_with_score
      |> Enum.map(fn {_, score} -> score end)
      |> Enum.max()

    cond do
      max_score == 0 ->
        {[], records}

      max_score < 5 ->
        # In this case, we want to split as little as possible otherwise
        # we'll end up splitting any comma.
        splitter =
          records_with_score
          |> Enum.reverse()
          |> Enum.find_index(fn {_, score} -> score == max_score end)

        take = length(records) - splitter

        {head, tail} = Enum.split(records, take)
        {[head], tail}

      true ->
        {ready_chunks, rest} =
          records_with_score
          |> split_chunked(fn {_, score} -> score == max_score end)

        ready =
          ready_chunks
          |> Enum.map(&Enum.map(&1, fn {x, _} -> x end))

        rest = Enum.map(rest, fn {x, _} -> x end)
        {ready, rest}
    end
  end

  defp fix_leading_punctuation([h1 | [h2 | tail]]) when h1.type == "punctuation",
    do: [%{h2 | from: h1.from} | tail]

  defp fix_leading_punctuation([h1]) when h1.type == "punctuation", do: []
  defp fix_leading_punctuation(records), do: records
end
