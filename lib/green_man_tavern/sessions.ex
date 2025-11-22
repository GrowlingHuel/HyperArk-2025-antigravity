defmodule GreenManTavern.Sessions do
  @moduledoc """
  The Sessions context for managing conversation sessions.

  This module provides functions for working with conversation sessions,
  which group related conversation_history records by session_id.

  ## Features

  - Generate unique session IDs
  - Retrieve all messages for a session
  - Check if a session exists
  - Get session metadata (message count, duration, etc.)

  ## Note

  This is a query layer on top of the existing Conversations context
  and conversation_history table. It does not duplicate functionality.
  """

  import Ecto.Query, warn: false
  alias GreenManTavern.Repo
  alias GreenManTavern.Conversations.ConversationHistory

  @doc """
  Generates a new UUID for a conversation session.

  ## Examples

      iex> generate_session_id()
      "550e8400-e29b-41d4-a716-446655440000"

  """
  def generate_session_id do
    Ecto.UUID.generate()
  end

  @doc """
  Retrieves all conversation_history records for a session, ordered by inserted_at.

  Returns messages in chronological order (oldest first).

  ## Examples

      iex> get_session_messages("550e8400-e29b-41d4-a716-446655440000")
      [%ConversationHistory{}, ...]

      iex> get_session_messages("nonexistent-session")
      []

  """
  def get_session_messages(session_id) when is_binary(session_id) do
    from(ch in ConversationHistory,
      where: ch.session_id == ^session_id,
      order_by: [asc: ch.inserted_at]
    )
    |> Repo.all()
  end

  @doc """
  Checks if a session has any messages.

  Returns `true` if at least one conversation_history record exists
  with the given session_id, `false` otherwise.

  ## Examples

      iex> session_exists?("550e8400-e29b-41d4-a716-446655440000")
      true

      iex> session_exists?("nonexistent-session")
      false

  """
  def session_exists?(session_id) when is_binary(session_id) do
    query =
      from(ch in ConversationHistory,
        where: ch.session_id == ^session_id,
        select: 1,
        limit: 1
      )

    case Repo.one(query) do
      1 -> true
      _ -> false
    end
  end

  @doc """
  Returns metadata about a session.

  Returns a map with:
  - `message_count` - number of messages in the session
  - `user_id` - user ID (from first message)
  - `character_id` - character ID (from first message)
  - `duration` - time in seconds between first and last message (nil if only one message)
  - `started_at` - timestamp of first message
  - `ended_at` - timestamp of last message

  Returns `nil` if the session does not exist.

  ## Examples

      iex> get_session_metadata("550e8400-e29b-41d4-a716-446655440000")
      %{
        message_count: 10,
        user_id: 1,
        character_id: 2,
        duration: 3600,
        started_at: ~N[2025-11-08 10:00:00],
        ended_at: ~N[2025-11-08 11:00:00]
      }

      iex> get_session_metadata("nonexistent-session")
      nil

  """
  def get_session_metadata(session_id) when is_binary(session_id) do
    # Get first and last messages to extract metadata
    messages = get_session_messages(session_id)

    case messages do
      [] ->
        nil

      [single_message] ->
        %{
          message_count: 1,
          user_id: single_message.user_id,
          character_id: single_message.character_id,
          duration: nil,
          started_at: single_message.inserted_at,
          ended_at: single_message.inserted_at
        }

      messages when is_list(messages) ->
        first_message = List.first(messages)
        last_message = List.last(messages)

        duration =
          if first_message.inserted_at && last_message.inserted_at do
            NaiveDateTime.diff(last_message.inserted_at, first_message.inserted_at, :second)
          else
            nil
          end

        %{
          message_count: length(messages),
          user_id: first_message.user_id,
          character_id: first_message.character_id,
          duration: duration,
          started_at: first_message.inserted_at,
          ended_at: last_message.inserted_at
        }
    end
  end
end
