defprotocol STT.Transcriber do
  @typedoc """
  The connection to a transcriber instance.
  """
  @type conn :: pid()

  @typedoc """
  Format of the audio buffers received by the transcriber.
  """
  @type format :: %{
          sample_rate: pos_integer(),
          sample_format: atom(),
          channels: non_neg_integer()
        }

  @spec required_stream_format(t()) :: format()
  def required_stream_format(transcriber)

  @spec supported_languages(t()) :: [String.t()]
  def supported_languages(transcriber)

  @spec language_code(t()) :: String.t()
  def language_code(t)

  @spec connect(t(), Keyword.t()) :: {:ok, conn()} | {:error, any()}
  def connect(transcriber, opts)

  @type record :: %{
          required(:from) => pos_integer(),
          required(:to) => pos_integer(),
          required(:text) => String.t(),
          required(:type) => String.t(),
          optional(:is_eos) => boolean(),
          optional(:speaker) => String.t()
        }

  @type transcript_payload :: %{
          # String representation of the spoken text.
          transcript: String.t(),
          # Unique ID of the sentence.
          id: String.t(),
          # Session identifier.
          session_id: String.t(),
          # Wether is is a partial or final record.
          is_partial: Boolean.t(),
          # The records of the spoken text.
          records: [record()],
          # Timing information of the transcript frame.
          from: pos_integer(),
          to: pos_integer()
        }

  @typedoc """
  Message delivered by the transcriber to the calling process. Termination
  messages follow OTP guidelines, i.e. on normal termination expect an EXIT
  with reason :normal
  """
  @type event :: {:stt, conn(), {:transcript, transcript_payload()}}

  @spec send_eos(t(), conn()) :: :ok
  def send_eos(transcriber, conn)

  @spec send_audio(t(), conn(), Membrane.Buffer.t()) :: :ok
  def send_audio(transcriber, conn, buffer)

  @spec sentence_boundary_detection_mode(t()) :: STT.Sentence.Builder.sbd_mode()
  def sentence_boundary_detection_mode(transcriber)
end
