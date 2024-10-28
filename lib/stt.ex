defmodule STT do
  def silence_record(start_time, end_time) do
    %{
      text: "",
      from: start_time,
      to: end_time,
      type: "silence",
      is_eos: true,
      speaker: nil
    }
  end

  @doc """
  Given a list of records and the time frame of the recognition window
  they are in, adds silence records to cover the portions not covered
  by the actual records. In case there are no actual records, returns
  one silent record that covers the entire window.

  start_time and end_time are in milliseconds.
  """
  @spec wrap_with_silence([STT.Transcriber.record()], pos_integer(), pos_integer()) :: [
          STT.Transcriber.record()
        ]
  def wrap_with_silence([], start_time, end_time) do
    [silence_record(start_time, end_time)]
  end

  def wrap_with_silence(results, start_time, end_time) do
    head = List.first(results)
    head_silence = head.from - start_time

    tail = List.last(results)
    tail_silence = end_time - tail.to

    List.flatten([
      if(head_silence > 0, do: [silence_record(start_time, head.from)], else: []),
      results,
      if(tail_silence > 0, do: [silence_record(tail.to, end_time)], else: [])
    ])
  end
end
