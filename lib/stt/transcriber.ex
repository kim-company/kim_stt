defprotocol STT.Transcriber do
  @typedoc """
  The connection to a transcriber instance.
  """
  @type conn :: pid()

  @typedoc """
  An audio buffer.
  """
  @type buffer :: %{payload: binary(), pts: pos_integer(), metadata: map()}

  @typedoc """
  Format of the audio buffers received by the transcriber.
  """
  @type format :: %{
          sample_rate: pos_integer(),
          sample_format: atom(),
          channels: non_neg_integer()
        }

  @typedoc """
  Message delivered by the transcriber to the calling process. Termination
  messages follow OTP guidelines, i.e. on normal termination expect an EXIT
  with reason :normal
  """
  @type event ::
          {:stt, conn(),
           {:transcript, session :: String.t(), is_partial :: boolean(), transcript :: String.t(),
            [STT.Record.t()]}}

  @spec required_input_pad_format(t()) :: format()
  def required_input_pad_format(transcriber)

  @spec connect(t(), Keyword.t()) :: {:ok, conn()} | {:error, any()}
  def connect(transcriber, opts)

  @spec close(t(), conn()) :: :ok
  def close(transcriber, conn)

  @spec send_audio_buffer(t(), conn(), buffer()) :: :ok
  def send_audio_buffer(transcriber, conn, buffer)

  @spec supported_languages(t()) :: [{String.t(), String.t()}]
  def supported_languages(transcriber)
end
