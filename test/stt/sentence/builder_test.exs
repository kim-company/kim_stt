defmodule STT.Sentence.BuilderTest do
  use ExUnit.Case

  alias STT.Sentence.Builder

  describe "builder" do
    setup do
      speechmatics =
        "test/data/babylon.json"
        |> File.read!()
        |> Jason.decode!(keys: :atoms)
        |> Enum.map(fn x ->
          # Produce batches of records.
          x.records
          # The builder is not ment to be used with partial records.
          |> Enum.reject(fn x -> x.is_partial end)
          |> Enum.map(fn x -> put_in(x, [:language_code], "en") end)
        end)
        # Taking out partials produces empty batches.
        |> Enum.reject(&Enum.empty?/1)

      %{speechmatics: speechmatics, builder: %Builder{}}
    end

    test "vod sentence production, eos mode", %{speechmatics: batched, builder: builder} do
      {sentences, builder} = build_sentences_no_silence(batched, builder)

      assert Builder.empty?(builder)

      want = [
        "We have to do that, you know, to get my attention.",
        "I am so sorry, Mr. Conrad.",
        "What's your name?",
        "Jen.",
        "I just wanted you to look my way.",
        "Jen.",
        "I'd always look your way.",
        "Sir George won't come out of the car.",
        "He's insisting I drive him off the nearest cliff.",
        "Right.",
        "Be right."
      ]

      have =
        sentences
        |> List.flatten()
        |> Enum.map(fn x -> to_string(x) end)

      assert want == have
    end

    test "vod sentence production, punctuation mode", %{speechmatics: batched, builder: builder} do
      builder = %Builder{builder | mode: :punctuation}

      {sentences, builder} = build_sentences_no_silence(batched, builder)

      assert Builder.empty?(builder)

      want = [
        "We have to do that, you know,",
        "to get my attention.",
        "I am so sorry, Mr. Conrad.",
        "What's your name?",
        "Jen.",
        "I just wanted you to look my way.",
        "Jen.",
        "I'd always look your way.",
        "Sir George won't come out of the car.",
        "He's insisting I drive him off the nearest cliff.",
        "Right.",
        "Be right."
      ]

      have =
        sentences
        |> List.flatten()
        |> Enum.map(fn x -> to_string(x) end)

      assert want == have
    end

    test "silence is isolated", %{builder: builder, speechmatics: batched} do
      {sentences, _builder} = Enum.flat_map_reduce(batched, builder, &Builder.put_and_get/2)

      sentences
      |> Enum.map(fn x ->
        # Either it is a sentence full of silence or does not
        # begin or end with it.
        if to_string(x) != "" do
          {pre_silence, during} =
            Enum.split_while(x.words, fn r -> r.type == "silence" or r.text == "" end)

          {post_silence, during} =
            during
            |> Enum.reverse()
            |> Enum.split_while(fn r -> r.type == "silence" or r.text == "" end)

          assert Enum.empty?(pre_silence)
          assert Enum.empty?(post_silence)
          refute Enum.empty?(during)
        end
      end)
    end

    test "splitting a sentence with commas", %{builder: builder} do
      recs =
        ~w/And so everyone just assumed these were sterile environments and then in the sort of late 90s , myself and a number/
        |> Enum.map(fn
          x = "," -> %{text: x, type: "punctuation"}
          x -> %{text: x, type: "word"}
        end)
        |> Enum.map(fn x -> put_in(x, [:language_code], "en") end)

      builder = %Builder{builder | mode: :punctuation}
      {[sentence], builder} = Enum.flat_map_reduce([recs], builder, &Builder.put_and_get/2)

      refute Builder.empty?(builder)

      assert to_string(sentence) ==
               "And so everyone just assumed these were sterile environments and then in the sort of late 90s,"
    end
  end

  defp build_sentences_no_silence(records_batched, builder) do
    {sentences, builder} =
      Enum.flat_map_reduce(records_batched, builder, &Builder.put_and_get/2)

    {Enum.filter(sentences, fn x -> to_string(x) != "" end), builder}
  end
end
