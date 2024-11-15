defmodule Slax.Chat.Room do
  use Ecto.Schema
  import Ecto.Changeset

  alias Slax.Accounts.User
  alias Slax.Chat.{Message, RoomMembership}

  schema "rooms" do
    field :name, :string
    field :topic, :string

    many_to_many :members, User, join_through: RoomMembership

    has_many :messages, Message

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(room, attrs) do
    room
    |> cast(attrs, [:name, :topic])
    |> validate_required([:name])
    |> validate_length(:name, max: 80)
    |> validate_format(:name, ~r/\A[a-z0-9-]+\z/,
      message: "can only contain lowercase letters, numbers and dashes"
    )
    |> validate_length(:topic, max: 200)
    |> unsafe_validate_unique(:name, Slax.Repo)
    |> unique_constraint(:name)
  end
end

defmodule Slax.Chat do
  alias Slax.Accounts.User
  alias Slax.Chat.{Message, Room, RoomMembership}
  alias Slax.Repo

  import Ecto.Query

  @pubsub Slax.PubSub

  def subscribe_to_room(room) do
    Phoenix.PubSub.subscribe(@pubsub, topic(room.id))
  end

  def unsubscribe_from_room(room) do
    Phoenix.PubSub.unsubscribe(@pubsub, topic(room.id))
  end

  defp topic(room_id), do: "chat_room:#{room_id}"

  def create_room(attrs) do
    %Room{}
    |> Room.changeset(attrs)
    |> Repo.insert()
  end

  def join_room!(room, user) do
    Repo.insert!(%RoomMembership{room: room, user: user})
  end

  def update_room(%Room{} = room, attrs) do
    room |> Room.changeset(attrs) |> Repo.update()
  end

  def change_room(room, attrs \\ %{}) do
    Room.changeset(room, attrs)
  end

  def get_room!(id) do
    Room |> Repo.get!(id)
  end

  def get_first_room! do
    Repo.one!(from r in Room, limit: 1, order_by: [asc: :name])
  end

  def list_rooms do
    Repo.all(from r in Room, order_by: [asc: :name])
  end

  def list_joined_rooms(%User{} = user) do
    user
    |> Repo.preload(:rooms)
    |> Map.fetch!(:rooms)
    |> Enum.sort_by(& &1.name)
  end

  def list_rooms_with_joined(%User{} = user) do
    query =
      from r in Room,
        left_join: m in RoomMembership,
        on: r.id == m.room_id and m.user_id == ^user.id,
        select: {r, not is_nil(m.id)},
        order_by: [asc: :name]

    Repo.all(query)
  end

  def joined?(%Room{} = room, %User{} = user) do
    Repo.exists?(
      from rm in RoomMembership, where: rm.room_id == ^room.id and rm.user_id == ^user.id
    )
  end

  def list_messages_in_room(%Room{id: room_id}) do
    from(m in Message,
      where: m.room_id == ^room_id,
      order_by: [asc: :inserted_at, asc: :id]
    )
    |> preload(:user)
    |> Repo.all()
  end

  def change_message(message, attrs \\ %{}) do
    Message.changeset(message, attrs)
  end

  def create_message(room, attrs, user) do
    with {:ok, message} <-
           %Message{room: room, user: user}
           |> Message.changeset(attrs)
           |> Repo.insert() do
      Phoenix.PubSub.broadcast!(@pubsub, topic(room.id), {:new_message, message})
      {:ok, message}
    end
  end

  def delete_message_by_id(id, %User{id: user_id}) do
    message = %Message{user_id: ^user_id} = Repo.get(Message, id)

    Repo.delete(message)

    Phoenix.PubSub.broadcast!(@pubsub, topic(message.room_id), {:message_deleted, message})
  end
end
