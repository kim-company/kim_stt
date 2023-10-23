defmodule STT.Sentence.BuilderTest do
  use ExUnit.Case

  alias STT.Record
  alias STT.Sentence

  # 1 second in nano seconds
  @max_silence 1_000_000_000

  describe "split_records/1" do
    test "with an empty list" do
      records = []
      assert [] == split_records(records)
    end

    test "splits by silence" do
      records = [
        make_record(10, 20, "hello"),
        make_record(2_000, 2_200, "world"),
        make_record(2_200, 2_500, "!", type: "punctuation")
      ]

      assert ["hello", "world!"] ==
               split_records(records) |> extract_text()
    end

    test "split by eos" do
      records = [
        make_record(10, 20, "look"),
        make_record(20, 30, "my"),
        make_record(50, 60, "way"),
        make_record(60, 60, ",", type: "punctuation"),
        make_record(100, 110, "Jen"),
        make_record(110, 110, ".", is_eos: true, type: "punctuation"),
        make_record(200, 210, "I"),
        make_record(220, 230, "will")
      ]

      assert ["look my way, Jen.", "I will"] ==
               split_records(records) |> extract_text()
    end

    test "split by punctuation" do
      records = [
        make_record(10, 20, "look"),
        make_record(20, 30, "my"),
        make_record(50, 60, "way"),
        make_record(60, 60, ",", type: "punctuation"),
        make_record(100, 110, "Jen"),
        make_record(110, 110, ".", type: "punctuation"),
        make_record(200, 210, "I"),
        make_record(220, 230, "will")
      ]

      assert ["look my way, Jen.", "I will"] ==
               split_records(records) |> extract_text()
    end

    test "split more than once" do
      records = [
        make_record(10, 20, "look"),
        make_record(2000, 2100, "my"),
        make_record(2100, 2200, "way"),
        make_record(2200, 2200, ".", type: "punctuation"),
        make_record(2300, 2400, "Jen")
      ]

      assert ["look", "my way.", "Jen"] ==
               split_records(records) |> extract_text()
    end
  end

  defp split_records(records) do
    builder = %Sentence.Builder{silence_split_threshold: @max_silence}
    {final_groups, builder} = Sentence.Builder.add_records(builder, records)
    {partials, _builder} = Sentence.Builder.flush(builder)

    final_groups ++ partials
  end

  defp make_record(from, to, text, opts \\ []) do
    type = Keyword.get(opts, :type, "pronunciation")
    is_eos = Keyword.get(opts, :is_eos, nil)

    %Record{
      from: from * 1_000_000,
      to: to * 1_000_000,
      text: text,
      type: type,
      is_eos: is_eos
    }
  end

  defp extract_text(records_grouped) do
    Enum.map(records_grouped, &to_string/1)
  end
end
