defmodule SlaxWeb.ChatRoomLive do
  use SlaxWeb, :live_view

  alias Slax.Chat
  alias Slax.Chat.{Room, Message}

  def render(assigns) do
    ~H"""
   <div class="flex flex-col flex-shrink-0 w-64 bg-slate-100">
     <div class="flex justify-between items-center flex-shrink-0 h-16 border-b border-slate-300 px-4">
       <div class="flex flex-col gap-1.5">
         <h1 class="text-lg font-bold text-gray-800">
           Slax
         </h1>
       </div>
     </div>
     <div class="mt-4 overflow-auto">
       <div class="flex items-center h-8 px-3 group">
         <span class="ml-2 leading-none font-medium text-sm">Rooms</span>
       </div>
       <div id="rooms-list">
         <.room_link :for={room <- @rooms} room={room} active={room.id == @room.id} />
       </div>
     </div>
   </div>
   <div class="flex flex-col flex-grow shadow-lg">
     <div class="flex justify-between items-center flex-shrink-0 h-16 bg-white border-b border-slate-300 px-4">
       <div class="flex flex-col gap-1.5">
         <h1 class="text-sm font-bold leading-none">
           #<%= @room.name %>
           <.link
           class="font-normal text-xs text-blue-600 hover:text-blue-700" navigate={~p"/rooms/#{@room}/edit"}>
            Edit
           </.link>
         </h1>
         <div class="text-xs leading-none h-3.5" phx-click="toggle-topic">
           <%= if @hide_topic? do %>
             <span class="text-slate-600">[Topic hidden]</span>
           <% else %>
             <%= @room.topic %>
           <% end %>
         </div>
       </div>
      <ul class="relative z-10 flex items-center gap-4 px-4 sm:px-6 lg:px-8 justify-end">
        <%= if @current_user do %>
          <li class="text-[0.8125rem] leading-6 text-zinc-900">
            <%=get_username(@current_user)%>
          </li>
          <li>
            <.link
              href={~p"/users/settings"}
              class="text-[0.8125rem] leading-6 text-zinc-900 font-semibold hover:text-zinc-700"
            >
              Settings
            </.link>
          </li>
          <li>
            <.link
              href={~p"/users/log_out"}
              method="delete"
              class="text-[0.8125rem] leading-6 text-zinc-900 font-semibold hover:text-zinc-700"
            >
              Log out
            </.link>
          </li>
        <% else %>
          <li>
            <.link
              href={~p"/users/register"}
              class="text-[0.8125rem] leading-6 text-zinc-900 font-semibold hover:text-zinc-700"
            >
              Register
            </.link>
          </li>
          <li>
            <.link
              href={~p"/users/log_in"}
              class="text-[0.8125rem] leading-6 text-zinc-900 font-semibold hover:text-zinc-700"
            >
              Log in
            </.link>
          </li>
        <% end %>
      </ul>
    </div>

    <div id="room-messages" phx-update="stream" class="flex flex-col flex-grow overflow-auto">
      <.message
        :for={{dom_id, message} <- @streams.messages}
        dom_id={dom_id}
        message={message}
        timezone={@timezone}
      />
     </div>
    <div class="h-12 bg-white px-4 pb-4">
    <.form
      id="new-message-form"
      for={@new_message_form}
      phx-change="validate-message"
      phx-submit="submit-message"
      class="flex items-center border-2 border-slate-300 rounded-sm p-1"
    >
      <textarea
        class="flex-grow text-sm px-3 border-l border-slate-300 mx-1 resize-none"
        cols=""
        id="chat-message-textarea"
        name={@new_message_form[:body].name}
        placeholder={"Message ##{@room.name}"}
        phx-debounce
        rows="1"
      ><%= Phoenix.HTML.Form.normalize_value("textarea", @new_message_form[:body].value) %></textarea>
      <button class="flex-shrink flex items-center justify-center h-6 w-6 rounded hover:bg-slate-200">
        <.icon name="hero-paper-airplane" class="h-4 w-4" />
      </button>
    </.form>
    </div>
   </div>
   """
  end

  attr :active, :boolean, required: true
  attr :room, Room, required: true

 defp room_link(assigns) do
   ~H"""
   <.link
     class={[
       "flex items-center h-8 text-sm pl-8 pr-3",
       (@active && "bg-slate-300") || "hover:bg-slate-300"
     ]}
     patch={~p"/rooms/#{@room}"}
   >
     <.icon name="hero-hashtag" class="h-4 w-4" />
     <span class={["ml-2 leading-none", @active && "font-bold"]}>
       <%= @room.name %>
     </span>
   </.link>
   """
 end

  attr :dom_id, :string, required: true
  attr :message, Message, required: true
  attr :timezone, :string, required: true

 defp message(assigns) do
  ~H"""
  <div id={@dom_id} class="relative flex px-4 py-3">
    <div class="h-10 w-10 rounded flex-shrink-0 bg-slate-300"></div>
    <div class="ml-2">
      <div class="-mt-1">
        <.link class="text-sm font-semibold hover:underline">
          <span><%=get_username(@message.user)%></span>
        </.link>
        <span :if={@timezone} class="ml-1 text-xs text-gray-500">
        <%= message_timestamp(@message, @timezone) %>
        </span>
        <p class="text-sm"><%= @message.body %></p>
      </div>
    </div>
  </div>
  """
 end

 defp get_username(user) do
   user.email |> String.split("@") |> List.first() |> String.capitalize()
 end

  def mount(_params, _session, socket) do
    rooms = Chat.list_rooms()
    timezone = get_connect_params(socket)["timezone"]

    {:ok, assign(socket, rooms: rooms, timezone: timezone)}
  end

  def handle_params(params, _session, socket) do
    room =
      case Map.fetch(params, "id") do
        {:ok, id} ->
          Chat.get_room!(id)

        :error ->
          Chat.get_first_room!()
      end

    messages = Chat.list_messages_in_room(room)

    {:noreply,
     socket
      |> assign(
       hide_topic?: false,
       page_title: "#" <> room.name,
       room: room
      )
      |> stream(:messages, messages, reset: true)
      |> assign_message_form(Chat.change_message(%Message{}))
    }
  end

  def handle_event("submit-message", %{"message" => message_params}, socket) do
    %{current_user: current_user, room: room} = socket.assigns

    socket =
      case Chat.create_message(room, message_params, current_user) do
        {:ok, message} ->
          socket
          |> stream_insert(:messages, message)
          |> assign_message_form(Chat.change_message(%Message{}))

        {:error, changeset} ->
          assign_message_form(socket, changeset)
      end

    {:noreply, socket}
  end

  def handle_event("toggle-topic", _params, socket) do
    {:noreply, update(socket, :hide_topic?, &(!&1))  }
  end

  def handle_event("validate-message", %{"message" => message_params}, socket) do
    changeset = Chat.change_message(%Message{}, message_params)
    {:noreply, assign_message_form(socket, changeset)}
  end

  defp assign_message_form(socket, changeset) do
    assign(socket, :new_message_form, to_form(changeset))
  end

  defp message_timestamp(message, timezone) do
    message.inserted_at
    |> Timex.Timezone.convert(timezone)
    |> Timex.format!("%-l:%M %p", :strftime)
  end
end
