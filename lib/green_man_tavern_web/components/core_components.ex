defmodule GreenManTavernWeb.CoreComponents do
  @moduledoc """
  Provides core UI components.

  At first glance, this module may seem daunting, but its goal is to provide
  core building blocks for your application, such as tables, forms, and
  inputs. The components consist mostly of markup and are well-documented
  with doc strings and declarative assigns. You may customize and style
  them in any way you want, based on your application growth and needs.

  The foundation for styling is Tailwind CSS, a utility-first CSS framework,
  augmented with daisyUI, a Tailwind CSS plugin that provides UI components
  and themes. Here are useful references:

    * [daisyUI](https://daisyui.com/docs/intro/) - a good place to get
      started and see the available components.

    * [Tailwind CSS](https://tailwindcss.com) - the foundational framework
      we build on. You will use it for layout, sizing, flexbox, grid, and
      spacing.

    * [Heroicons](https://heroicons.com) - see `icon/1` for usage.

    * [Phoenix.Component](https://hexdocs.pm/phoenix_live_view/Phoenix.Component.html) -
      the component system used by Phoenix. Some components, such as `<.link>`
      and `<.form>`, are defined there.

  """
  use Phoenix.Component
  use Gettext, backend: GreenManTavernWeb.Gettext

  alias Phoenix.LiveView.JS

  @doc """
  Renders flash notices.

  ## Examples

      <.flash kind={:info} flash={@flash} />
      <.flash kind={:info} phx-mounted={show("#flash")}>Welcome Back!</.flash>
  """
  attr :id, :string, doc: "the optional id of flash container"
  attr :flash, :map, default: %{}, doc: "the map of flash messages to display"
  attr :title, :string, default: nil
  attr :kind, :atom, values: [:info, :error], doc: "used for styling and flash lookup"
  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the flash container"

  slot :inner_block, doc: "the optional inner block that renders the flash message"

  def flash(assigns) do
    assigns = assign_new(assigns, :id, fn -> "flash-#{assigns.kind}" end)

    ~H"""
    <div
      :if={msg = render_slot(@inner_block) || Phoenix.Flash.get(@flash, @kind)}
      id={@id}
      phx-click={JS.push("lv:clear-flash", value: %{key: @kind}) |> hide("##{@id}")}
      role="alert"
      class="toast toast-top toast-end z-50"
      {@rest}
    >
      <div class={[
        "alert w-80 sm:w-96 max-w-80 sm:max-w-96 text-wrap",
        @kind == :info && "alert-info",
        @kind == :error && "alert-error"
      ]}>
        <.icon :if={@kind == :info} name="hero-information-circle" class="size-5 shrink-0" />
        <.icon :if={@kind == :error} name="hero-exclamation-circle" class="size-5 shrink-0" />
        <div>
          <p :if={@title} class="font-semibold">{@title}</p>
          <p>{msg}</p>
        </div>
        <div class="flex-1" />
        <button type="button" class="group self-start cursor-pointer" aria-label={gettext("close")}>
          <.icon name="hero-x-mark" class="size-5 opacity-40 group-hover:opacity-70" />
        </button>
      </div>
    </div>
    """
  end

  @doc """
  Renders a button with navigation support.

  ## Examples

      <.button>Send!</.button>
      <.button phx-click="go" variant="primary">Send!</.button>
      <.button navigate={~p"/"}>Home</.button>
  """
  attr :rest, :global, include: ~w(href navigate patch method download name value disabled)
  attr :class, :string
  attr :variant, :string, values: ~w(primary)
  slot :inner_block, required: true

  def button(%{rest: rest} = assigns) do
    variants = %{"primary" => "btn-primary", nil => "btn-primary btn-soft"}

    assigns =
      assign_new(assigns, :class, fn ->
        ["btn", Map.fetch!(variants, assigns[:variant])]
      end)

    if rest[:href] || rest[:navigate] || rest[:patch] do
      ~H"""
      <.link class={@class} {@rest}>
        {render_slot(@inner_block)}
      </.link>
      """
    else
      ~H"""
      <button class={@class} {@rest}>
        {render_slot(@inner_block)}
      </button>
      """
    end
  end

  @doc """
  Renders an input with label and error messages.

  A `Phoenix.HTML.FormField` may be passed as argument,
  which is used to retrieve the input name, id, and values.
  Otherwise all attributes may be passed explicitly.

  ## Types

  This function accepts all HTML input types, considering that:

    * You may also set `type="select"` to render a `<select>` tag

    * `type="checkbox"` is used exclusively to render boolean values

    * For live file uploads, see `Phoenix.Component.live_file_input/1`

  See https://developer.mozilla.org/en-US/docs/Web/HTML/Element/input
  for more information. Unsupported types, such as hidden and radio,
  are best written directly in your templates.

  ## Examples

      <.input field={@form[:email]} type="email" />
      <.input name="my-input" errors={["oh no!"]} />
  """
  attr :id, :any, default: nil
  attr :name, :any
  attr :label, :string, default: nil
  attr :value, :any

  attr :type, :string,
    default: "text",
    values: ~w(checkbox color date datetime-local email file month number password
               search select tel text textarea time url week)

  attr :field, Phoenix.HTML.FormField,
    doc: "a form field struct retrieved from the form, for example: @form[:email]"

  attr :errors, :list, default: []
  attr :checked, :boolean, doc: "the checked flag for checkbox inputs"
  attr :prompt, :string, default: nil, doc: "the prompt for select inputs"
  attr :options, :list, doc: "the options to pass to Phoenix.HTML.Form.options_for_select/2"
  attr :multiple, :boolean, default: false, doc: "the multiple flag for select inputs"
  attr :class, :string, default: nil, doc: "the input class to use over defaults"
  attr :error_class, :string, default: nil, doc: "the input error class to use over defaults"

  attr :rest, :global,
    include: ~w(accept autocomplete capture cols disabled form list max maxlength min minlength
                multiple pattern placeholder readonly required rows size step)

  def input(%{field: %Phoenix.HTML.FormField{} = field} = assigns) do
    errors = if Phoenix.Component.used_input?(field), do: field.errors, else: []

    assigns
    |> assign(field: nil, id: assigns.id || field.id)
    |> assign(:errors, Enum.map(errors, &translate_error(&1)))
    |> assign_new(:name, fn -> if assigns.multiple, do: field.name <> "[]", else: field.name end)
    |> assign_new(:value, fn -> field.value end)
    |> input()
  end

  def input(%{type: "checkbox"} = assigns) do
    assigns =
      assign_new(assigns, :checked, fn ->
        Phoenix.HTML.Form.normalize_value("checkbox", assigns[:value])
      end)

    ~H"""
    <div class="fieldset mb-2">
      <label>
        <input type="hidden" name={@name} value="false" disabled={@rest[:disabled]} />
        <span class="label">
          <input
            type="checkbox"
            id={@id}
            name={@name}
            value="true"
            checked={@checked}
            class={@class || "checkbox checkbox-sm"}
            {@rest}
          />{@label}
        </span>
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  def input(%{type: "select"} = assigns) do
    ~H"""
    <div class="fieldset mb-2">
      <label>
        <span :if={@label} class="label mb-1">{@label}</span>
        <select
          id={@id}
          name={@name}
          class={[@class || "w-full select", @errors != [] && (@error_class || "select-error")]}
          multiple={@multiple}
          {@rest}
        >
          <option :if={@prompt} value="">{@prompt}</option>
          {Phoenix.HTML.Form.options_for_select(@options, @value)}
        </select>
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  def input(%{type: "textarea"} = assigns) do
    ~H"""
    <div class="fieldset mb-2">
      <label>
        <span :if={@label} class="label mb-1">{@label}</span>
        <textarea
          id={@id}
          name={@name}
          class={[
            @class || "w-full textarea",
            @errors != [] && (@error_class || "textarea-error")
          ]}
          {@rest}
        >{Phoenix.HTML.Form.normalize_value("textarea", @value)}</textarea>
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  # All other inputs text, datetime-local, url, password, etc. are handled here...
  def input(assigns) do
    ~H"""
    <div class="fieldset mb-2">
      <label>
        <span :if={@label} class="label mb-1">{@label}</span>
        <input
          type={@type}
          name={@name}
          id={@id}
          value={Phoenix.HTML.Form.normalize_value(@type, @value)}
          class={[
            @class || "w-full input",
            @errors != [] && (@error_class || "input-error")
          ]}
          {@rest}
        />
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  # Helper used by inputs to generate form errors
  defp error(assigns) do
    ~H"""
    <p class="mt-1.5 flex gap-2 items-center text-sm text-error">
      <.icon name="hero-exclamation-circle" class="size-5" />
      {render_slot(@inner_block)}
    </p>
    """
  end

  @doc """
  Renders a header with title.
  """
  slot :inner_block, required: true
  slot :subtitle
  slot :actions

  def header(assigns) do
    ~H"""
    <header class={[@actions != [] && "flex items-center justify-between gap-6", "pb-4"]}>
      <div>
        <h1 class="text-lg font-semibold leading-8">
          {render_slot(@inner_block)}
        </h1>
        <p :if={@subtitle != []} class="text-sm text-base-content/70">
          {render_slot(@subtitle)}
        </p>
      </div>
      <div class="flex-none">{render_slot(@actions)}</div>
    </header>
    """
  end

  @doc """
  Renders a table with generic styling.

  ## Examples

      <.table id="users" rows={@users}>
        <:col :let={user} label="id">{user.id}</:col>
        <:col :let={user} label="username">{user.username}</:col>
      </.table>
  """
  attr :id, :string, required: true
  attr :rows, :list, required: true
  attr :row_id, :any, default: nil, doc: "the function for generating the row id"
  attr :row_click, :any, default: nil, doc: "the function for handling phx-click on each row"

  attr :row_item, :any,
    default: &Function.identity/1,
    doc: "the function for mapping each row before calling the :col and :action slots"

  slot :col, required: true do
    attr :label, :string
  end

  slot :action, doc: "the slot for showing user actions in the last table column"

  def table(assigns) do
    assigns =
      with %{rows: %Phoenix.LiveView.LiveStream{}} <- assigns do
        assign(assigns, row_id: assigns.row_id || fn {id, _item} -> id end)
      end

    ~H"""
    <table class="table table-zebra">
      <thead>
        <tr>
          <th :for={col <- @col}>{col[:label]}</th>
          <th :if={@action != []}>
            <span class="sr-only">{gettext("Actions")}</span>
          </th>
        </tr>
      </thead>
      <tbody id={@id} phx-update={is_struct(@rows, Phoenix.LiveView.LiveStream) && "stream"}>
        <tr :for={row <- @rows} id={@row_id && @row_id.(row)}>
          <td
            :for={col <- @col}
            phx-click={@row_click && @row_click.(row)}
            class={@row_click && "hover:cursor-pointer"}
          >
            {render_slot(col, @row_item.(row))}
          </td>
          <td :if={@action != []} class="w-0 font-semibold">
            <div class="flex gap-4">
              <%= for action <- @action do %>
                {render_slot(action, @row_item.(row))}
              <% end %>
            </div>
          </td>
        </tr>
      </tbody>
    </table>
    """
  end

  @doc """
  Renders a data list.

  ## Examples

      <.list>
        <:item title="Title">{@post.title}</:item>
        <:item title="Views">{@post.views}</:item>
      </.list>
  """
  slot :item, required: true do
    attr :title, :string, required: true
  end

  def list(assigns) do
    ~H"""
    <ul class="list">
      <li :for={item <- @item} class="list-row">
        <div class="list-col-grow">
          <div class="font-bold">{item.title}</div>
          <div>{render_slot(item)}</div>
        </div>
      </li>
    </ul>
    """
  end

  @doc """
  Renders a [Heroicon](https://heroicons.com).

  Heroicons come in three styles – outline, solid, and mini.
  By default, the outline style is used, but solid and mini may
  be applied by using the `-solid` and `-mini` suffix.

  You can customize the size and colors of the icons by setting
  width, height, and background color classes.

  Icons are extracted from the `deps/heroicons` directory and bundled within
  your compiled app.css by the plugin in `assets/vendor/heroicons.js`.

  ## Examples

      <.icon name="hero-x-mark" />
      <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
  """
  attr :name, :string, required: true
  attr :class, :string, default: "size-4"

  def icon(%{name: "hero-" <> _} = assigns) do
    ~H"""
    <span class={[@name, @class]} />
    """
  end

  @doc """
  Renders a greyscale planting guide icon.

  Icons: :seed, :seedling, :warning, :calendar, :leaf, :info, :check, :x
  """
  attr :name, :atom, required: true, values: [:seed, :seedling, :warning, :calendar, :leaf, :info, :check, :x, :eye, :clock, :basket]
  attr :class, :string, default: "inline-block"
  attr :size, :integer, default: 14
  attr :style, :string, default: ""
  attr :stroke_color, :string, default: "#000"
  attr :fill_color, :string, default: "#000"

  def planting_icon(assigns) do

    ~H"""
    <svg
      class={@class}
      width={@size}
      height={@size}
      viewBox="0 0 16 16"
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
      style={["vertical-align: middle;", @style]}
    >
      <%= case @name do %>
        <% :seed -> %>
          <%!-- Seedling sprout icon --%>
          <path d="M4 14L4 10" stroke={@stroke_color} stroke-width="1.5" stroke-linecap="round"/>
          <path d="M8 14L8 10" stroke={@stroke_color} stroke-width="1.5" stroke-linecap="round"/>
          <path d="M6 10C6 8 6.5 6 8 4C9.5 6 10 8 10 10" stroke={@stroke_color} stroke-width="1.5" stroke-linecap="round" fill="none"/>
          <circle cx="4" cy="10" r="1.5" fill={@fill_color}/>
          <circle cx="8" cy="10" r="1.5" fill={@fill_color}/>
        <% :seedling -> %>
          <%!-- Mature seedling icon --%>
          <path d="M8 14L8 6" stroke={@stroke_color} stroke-width="1.5" stroke-linecap="round"/>
          <path d="M8 6C8 4 7 2 5 2C3 2 2 4 2 6" stroke={@stroke_color} stroke-width="1.5" fill="none"/>
          <path d="M8 6C8 4 9 2 11 2C13 2 14 4 14 6" stroke={@stroke_color} stroke-width="1.5" fill="none"/>
          <path d="M5 8L3 10" stroke={@stroke_color} stroke-width="1.5" stroke-linecap="round"/>
          <path d="M11 8L13 10" stroke={@stroke_color} stroke-width="1.5" stroke-linecap="round"/>
        <% :warning -> %>
          <%!-- Warning triangle --%>
          <path d="M8 2L2 14L14 14L8 2Z" stroke={@stroke_color} stroke-width="1.5" fill="none" stroke-linejoin="round"/>
          <path d="M8 9L8 11" stroke={@stroke_color} stroke-width="1.5" stroke-linecap="round"/>
          <circle cx="8" cy="12.5" r="0.8" fill={@fill_color}/>
        <% :calendar -> %>
          <%!-- Calendar icon --%>
          <rect x="2" y="3" width="12" height="11" rx="1" stroke={@stroke_color} stroke-width="1.5" fill="none"/>
          <path d="M2 6L14 6" stroke={@stroke_color} stroke-width="1.5"/>
          <path d="M5 1L5 4" stroke={@stroke_color} stroke-width="1.5" stroke-linecap="round"/>
          <path d="M11 1L11 4" stroke={@stroke_color} stroke-width="1.5" stroke-linecap="round"/>
          <circle cx="5" cy="9" r="0.8" fill={@fill_color}/>
          <circle cx="8" cy="9" r="0.8" fill={@fill_color}/>
          <circle cx="11" cy="9" r="0.8" fill={@fill_color}/>
        <% :leaf -> %>
          <%!-- Falling leaf --%>
          <path d="M8 2C6 4 4 6 4 8C4 10 5 11 6 12" stroke={@stroke_color} stroke-width="1.5" fill="none" stroke-linecap="round"/>
          <path d="M8 2C10 4 12 6 12 8C12 10 11 11 10 12" stroke={@stroke_color} stroke-width="1.5" fill="none" stroke-linecap="round"/>
          <path d="M6 12L5 14" stroke={@stroke_color} stroke-width="1.5" stroke-linecap="round"/>
          <path d="M10 12L11 14" stroke={@stroke_color} stroke-width="1.5" stroke-linecap="round"/>
        <% :info -> %>
          <%!-- Info circle --%>
          <circle cx="8" cy="8" r="6" stroke={@stroke_color} stroke-width="1.5" fill="none"/>
          <path d="M8 5L8 7" stroke={@stroke_color} stroke-width="1.5" stroke-linecap="round"/>
          <path d="M8 9L8 11" stroke={@stroke_color} stroke-width="1.5" stroke-linecap="round"/>
        <% :check -> %>
          <%!-- Checkmark --%>
          <circle cx="8" cy="8" r="6" stroke={@stroke_color} stroke-width="1.5" fill="none"/>
          <path d="M5 8L7 10L11 6" stroke={@stroke_color} stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" fill="none"/>
        <% :x -> %>
          <%!-- X mark --%>
          <circle cx="8" cy="8" r="6" stroke={@stroke_color} stroke-width="1.5" fill="none"/>
          <path d="M5 5L11 11M11 5L5 11" stroke={@stroke_color} stroke-width="1.5" stroke-linecap="round"/>
        <% :eye -> %>
          <%!-- Eye icon (interested) --%>
          <ellipse cx="8" cy="8" rx="5" ry="3" stroke={@stroke_color} stroke-width="1.5" fill="none"/>
          <circle cx="8" cy="8" r="1.5" fill={@fill_color}/>
          <path d="M3 6L2 5M13 6L14 5M3 10L2 11M13 10L14 11" stroke={@stroke_color} stroke-width="1.5" stroke-linecap="round"/>
        <% :clock -> %>
          <%!-- Clock icon (will plant) --%>
          <circle cx="8" cy="8" r="5" stroke={@stroke_color} stroke-width="1.5" fill="none"/>
          <path d="M8 5L8 8L10 10" stroke={@stroke_color} stroke-width="1.5" stroke-linecap="round"/>
        <% :basket -> %>
          <%!-- Basket icon (harvested) --%>
          <path d="M3 6L4 13L12 13L13 6" stroke={@stroke_color} stroke-width="1.5" fill="none" stroke-linejoin="round"/>
          <path d="M3 6L2 4L14 4L13 6" stroke={@stroke_color} stroke-width="1.5" fill="none"/>
          <path d="M6 10L8 10M10 10L8 10" stroke={@stroke_color} stroke-width="1.5" stroke-linecap="round"/>
      <% end %>
    </svg>
    """
  end

  @doc """
  Renders a custom status dropdown with SVG icons.

  Options should be a list of {value, label, icon_name} tuples.
  """
  attr :id, :string, required: true
  attr :name, :string, required: true
  attr :value, :string, default: ""
  attr :options, :list, required: true
  attr :form_id, :string, required: true
  attr :plant_id, :integer, required: true
  attr :class, :string, default: ""

  def status_dropdown(assigns) do
    ~H"""
    <div class={["custom-status-dropdown", @class]} phx-hook="CustomDropdown" id={"dropdown-#{@id}"} style="position: relative;">
      <input type="hidden" name={@name} id={@id} value={@value} form={@form_id} />
      <div
        class="dropdown-trigger"
        style="width: 100%; padding: 8px; border: 2px solid black; background: white; font-size: 13px; cursor: pointer; display: flex; align-items: center; justify-content: space-between; font-family: Georgia, 'Times New Roman', serif;"
      >
        <span style="display: flex; align-items: center; gap: 6px;">
          <%= if @value != "" do %>
            <% {_, label, icon_name} = Enum.find(@options, fn {val, _, _} -> val == @value end) || {nil, "Select Status", nil} %>
            <%= if icon_name do %>
              <.planting_icon name={icon_name} size={14} />
            <% end %>
            <span><%= label %></span>
          <% else %>
            <span>-- Select Status --</span>
          <% end %>
        </span>
        <span style="font-size: 10px;">▼</span>
      </div>
      <div
        class="dropdown-options"
        style="display: none; position: absolute; width: 100%; background: white; border: 2px solid black; border-top: none; z-index: 1000; box-shadow: 2px 2px 0 rgba(0,0,0,0.3); max-height: 200px; overflow-y: auto;"
      >
        <%= for {option_value, label, icon_name} <- @options do %>
          <div
            class={["dropdown-option", if(@value == option_value, do: "selected", else: "")]}
            data-value={option_value}
            style={[
              "padding: 8px; cursor: pointer; display: flex; align-items: center; gap: 6px;",
              "font-family: Georgia, 'Times New Roman', serif;",
              "font-size: 13px; border-bottom: 1px solid #ddd;",
              if(@value == option_value, do: "background: #f0f0f0;", else: ""),
              "&:hover { background: #f5f5f5; }"
            ]}
            onmouseover="this.style.background='#f5f5f5'"
            onmouseout={if(@value == option_value, do: "this.style.background='#f0f0f0'", else: "this.style.background='white'")}
          >
            <%= if icon_name do %>
              <.planting_icon name={icon_name} size={14} />
            <% end %>
            <span><%= label %></span>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  ## JS Commands

  def show(js \\ %JS{}, selector) do
    JS.show(js,
      to: selector,
      time: 300,
      transition:
        {"transition-all ease-out duration-300",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95",
         "opacity-100 translate-y-0 sm:scale-100"}
    )
  end

  def hide(js \\ %JS{}, selector) do
    JS.hide(js,
      to: selector,
      time: 200,
      transition:
        {"transition-all ease-in duration-200", "opacity-100 translate-y-0 sm:scale-100",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95"}
    )
  end

  @doc """
  Translates an error message using gettext.
  """
  def translate_error({msg, opts}) do
    # When using gettext, we typically pass the strings we want
    # to translate as a static argument:
    #
    #     # Translate the number of files with plural rules
    #     dngettext("errors", "1 file", "%{count} files", count)
    #
    # However the error messages in our forms and APIs are generated
    # dynamically, so we need to translate them by calling Gettext
    # with our gettext backend as first argument. Translations are
    # available in the errors.po file (as we use the "errors" domain).
    if count = opts[:count] do
      Gettext.dngettext(GreenManTavernWeb.Gettext, "errors", msg, msg, count, opts)
    else
      Gettext.dgettext(GreenManTavernWeb.Gettext, "errors", msg, opts)
    end
  end

  @doc """
  Translates the errors for a field from a keyword list of errors.
  """
  def translate_errors(errors, field) when is_list(errors) do
    for {^field, {msg, opts}} <- errors, do: translate_error({msg, opts})
  end
end
