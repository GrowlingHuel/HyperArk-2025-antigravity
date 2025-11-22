defmodule GreenManTavernWeb.TavernPanelComponent do
  use GreenManTavernWeb, :live_component
  alias GreenManTavern.Characters
  alias GreenManTavernWeb.TextFormattingHelpers

  def render(assigns) do
    ~H"""
    <div class="dual-left-panel" style="margin: 0 !important; margin-left: 0 !important; margin-right: 0 !important; padding: 0 !important; padding-left: 0 !important; padding-top: 20px !important; left: 0 !important; position: relative !important;">
      <div class="panel-header panel-header-left" style="height: 20px !important; min-height: 20px !important; max-height: 20px !important; background: #BBBBBB !important; border-bottom: 2px solid #000 !important; padding: 0 8px !important; display: flex !important; align-items: center !important; font-family: Georgia, 'Times New Roman', serif !important; font-size: 11px !important; font-weight: bold !important; flex-shrink: 0 !important; position: fixed !important; top: 38px !important; left: 0 !important; width: 50vw !important; max-width: 50vw !important; visibility: visible !important; opacity: 1 !important; color: #000 !important; line-height: 20px !important; margin: 0 !important; padding-top: 0 !important; padding-bottom: 0 !important; margin-top: 0 !important; margin-bottom: 0 !important; box-sizing: border-box !important; z-index: 999 !important;">
        <%= case @view do %>
          <% :tavern_home -> %>
            Green Man Tavern
          <% :character_chat -> %>
            Chat with {@selected_character.name}
        <% end %>
      </div>
      <div class="panel-content" phx-hook="ScrollableContent" id="left-panel-content" style="margin-top: 0 !important; padding-top: 0 !important;">
        <%= case @view do %>
          <% :tavern_home -> %>
            <h2>Welcome to the Green Man Tavern</h2>
            <p>There are all manner of characters here with stories to tell. <em>Perhaps one of them can help you discover what to do next?</em></p>
            <div style="margin-top: 20px; margin-left: 2px; margin-right: 2px; text-align: center;">
              <img src="/images/the_tavern.png" alt="Tavern" style="width: calc(100% - 4px); max-width: 100%; border: 1px solid #000; display: block; margin: 0 auto;" />
            </div>
            <%= if assigns[:characters] && length(@characters) > 0 do %>
              <div style="margin-top: 16px; border-top: 1px solid #000; padding-top: 12px;">
                <div style="display: grid; grid-template-columns: repeat(3, 1fr); gap: 6px;">
                  <%= for character <- @characters do %>
                    <div
                      phx-click="select_character"
                      phx-value-character_slug={Characters.name_to_slug(character.name)}
                      style="border: 1px solid #000; background: #FFF; padding: 6px; cursor: pointer; display: flex; gap: 6px; align-items: center;"
                    >
                      <div class="char-card" style="width: 36px; height: 36px; flex-shrink: 0; border: 1px solid #000; display: flex; align-items: center; justify-content: center; background: #EEE;">
                        <img
                          src={TextFormattingHelpers.character_emoji(character.name)}
                          alt={character.name}
                          style="width: 24px; height: 24px; object-fit: contain; filter: grayscale(100%) !important;"
                        />
                      </div>
                      <div style="flex: 1; min-width: 0;">
                        <div style="font-weight: bold; font-size: 13px;">{character.name}</div>
                        <div style="font-size: 10px; color: #666;">{character.archetype}</div>
                      </div>
                    </div>
                  <% end %>
                </div>
              </div>
            <% else %>
              <p style="color: #999; font-style: italic; text-align: center; margin-top: 12px;">No characters found.</p>
            <% end %>

          <% :character_chat -> %>
            <div>
              <div style="margin-bottom: 12px; text-align: center;">
                <img src="/images/the_tavern.png" alt="Tavern" style="max-width: 100%; border: 1px solid #000;" />
              </div>
              <h2 style="display: flex; align-items: center; gap: 8px;">
                <img
                  src={TextFormattingHelpers.character_emoji(@selected_character.name)}
                  alt={@selected_character.name}
                  style="width: 32px; height: 32px; object-fit: contain; filter: grayscale(100%) !important;"
                />
                {@selected_character.name}
              </h2>
              <p style="color: #666; font-size: 11px;">{@selected_character.archetype}</p>

              <!-- Chat messages -->
              <div style="margin: 12px 0;">
                <h3 style="font-size: 13px; margin-bottom: 8px; font-family: Georgia, 'Times New Roman', serif;">Chat</h3>
                <style>
                  #chat-messages p { margin: 0 0 12px 0; padding: 0; text-indent: 1em; line-height: 1.5; font-size: 15px; }
                  #chat-messages p:first-child { margin-top: 0; }
                  #chat-messages p:last-child { margin-bottom: 0; }
                  #chat-messages strong { font-weight: bold; color: #000; font-size: 15px; }
                  #chat-messages em { font-style: italic; font-size: 15px; }
                  #chat-messages ul, #chat-messages ol { margin: 8px 0 8px 24px; padding: 0; line-height: 1.5; font-size: 15px; }
                  #chat-messages ul { list-style-type: disc; }
                  #chat-messages ol { list-style-type: decimal; }
                  #chat-messages li { margin-bottom: 4px; font-size: 15px; }
                  #chat-messages h1, #chat-messages h2, #chat-messages h3, #chat-messages h4, #chat-messages h5, #chat-messages h6 { margin: 12px 0 8px 0; font-weight: bold; line-height: 1.3; }
                  #chat-messages h1 { font-size: 20px; }
                  #chat-messages h2 { font-size: 18px; }
                  #chat-messages h3 { font-size: 16px; }
                  #chat-messages h4 { font-size: 15px; }
                  #chat-messages h5 { font-size: 15px; }
                  #chat-messages h6 { font-size: 15px; }
                  #chat-messages blockquote { margin: 8px 0 8px 16px; padding-left: 12px; border-left: 2px solid #999; font-style: italic; color: #555; font-size: 15px; }
                  #chat-messages code { background: #EEE; padding: 2px 4px; border: 1px solid #CCC; font-family: Georgia, 'Times New Roman', serif; font-size: 13px; }
                  #chat-messages pre { background: #EEE; padding: 8px; border: 1px solid #CCC; overflow-x: auto; margin: 8px 0; font-family: Georgia, 'Times New Roman', serif; font-size: 13px; line-height: 1.4; }
                  #chat-messages pre code { background: transparent; padding: 0; border: none; }
                </style>
                <div id="chat-messages" style="height: 600px; border: 1px solid #CCC; padding: 8px; overflow-y: auto; font-size: 15px; font-family: Georgia, 'Times New Roman', serif; line-height: 1.15;">
                  <%= if @chat_messages && length(@chat_messages) > 0 do %>
                    <%
                      # Process messages with term tracking (first occurrence only in conversation)
                      characters_list = if assigns[:characters], do: @characters, else: []
                      processed_messages = TextFormattingHelpers.process_chat_messages(@chat_messages, characters_list)
                    %>
                    <%= for {message, segments, msg_type} <- processed_messages do %>
                      <%= if message.type == :user do %>
                        <div style="margin-bottom: 8px; padding: 4px; text-align: right;">
                          <div style="display: inline-block; max-width: 90%; text-align: left;">
                            <strong style="color: #666; font-size: 15px; display: block; font-family: Georgia, 'Times New Roman', serif; line-height: 1.15;">You</strong>
                            <div style="color: #333; border: 1px solid #999; background: #FFF; padding: 4px; font-size: 15px; font-family: Georgia, 'Times New Roman', serif; line-height: 1.15;"><%= TextFormattingHelpers.render_segments(segments) %></div>
                          </div>
                        </div>
                      <% else %>
                        <div style="margin-bottom: 8px; padding: 4px; text-align: left;">
                          <div style="display: inline-block; max-width: 90%; text-align: left;">
                            <div style="display: flex; align-items: center; gap: 6px; margin-bottom: 2px;">
                              <img
                                src={TextFormattingHelpers.character_emoji(@selected_character.name)}
                                alt={@selected_character.name}
                                style="width: 18px; height: 18px; object-fit: contain; filter: grayscale(100%) !important; flex-shrink: 0;"
                              />
                              <strong style="color: #666; font-size: 15px; font-family: Georgia, 'Times New Roman', serif; line-height: 1.15;">{@selected_character.name}</strong>
                            </div>
                            <%!-- CRITICAL: Character messages are pre-converted to HTML in process_chat_messages (markdown→HTML→term identification) --%>
                            <%!-- Pass html: true so text segments are rendered as raw HTML (not escaped, not re-processed) --%>
                            <div style="color: #333; border: 1px solid #999; background: #FFF; padding: 4px; font-size: 15px; font-family: Georgia, 'Times New Roman', serif; line-height: 1.15;"><%= TextFormattingHelpers.render_segments(segments, html: true) %></div>
                          </div>
                        </div>
                      <% end %>
                    <% end %>
                    <%= if @is_loading do %>
                      <div style="margin-bottom: 8px; padding: 4px; text-align: left;">
                        <div style="display: inline-block; max-width: 90%; text-align: left;">
                            <div style="display: flex; align-items: center; gap: 6px; margin-bottom: 2px;">
                              <img
                                src={TextFormattingHelpers.character_emoji(@selected_character.name)}
                                alt={@selected_character.name}
                                style="width: 18px; height: 18px; object-fit: contain; filter: grayscale(100%) !important; flex-shrink: 0;"
                              />
                              <strong style="color: #666; font-size: 13px; font-family: Georgia, 'Times New Roman', serif; line-height: 1.15;">{@selected_character.name}</strong>
                            </div>
                          <div style="border: 1px solid #999; background: #FFF; padding: 4px; color: #666; display: flex; align-items: center; gap: 6px; font-size: 13px; font-family: Georgia, 'Times New Roman', serif; line-height: 1.15;">
                            <span>Thinking</span>
                            <span id="thinking-dots" class="thinking-dots" phx-hook="ThinkingDots" aria-label="Character is thinking" role="status">
                              <span class="dot"></span>
                              <span class="dot"></span>
                              <span class="dot"></span>
                            </span>
                          </div>
                        </div>
                      </div>
                    <% end %>
                  <% else %>
                    <p style="color: #999; font-style: italic; text-align: center; font-size: 13px; font-family: Georgia, 'Times New Roman', serif; line-height: 1.15;">Start a conversation...</p>
                  <% end %>
                </div>

                <!-- Chat form -->
                <.form for={to_form(%{}, as: :chat)} phx-submit="send_message">
                  <input
                    type="text"
                    name="message"
                    value={@current_message || ""}
                    placeholder="Type your message..."
                    style="width: 100%; padding: 6px; border: 1px solid #CCC; font-size: 13px; font-family: Georgia, 'Times New Roman', serif; line-height: 1.15; margin-top: 8px;"
                  />
                  <button type="submit" disabled={@is_loading} style="margin-top: 4px; padding: 4px 12px; background: #CCC; border: 1px solid #000; font-size: 13px; font-family: Georgia, 'Times New Roman', serif; line-height: 1.15;">
                    {if @is_loading, do: "Sending...", else: "Send"}
                  </button>
                </.form>
              </div>
            </div>
        <% end %>
      </div>
    </div>
    """
  end
end
