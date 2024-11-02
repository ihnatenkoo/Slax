defmodule Slax.Chat do
  alias Slax.Chat.Room
  alias Slax.Repo

  import Ecto.Query

  def get_room!(id) do
   Room |> Repo.get!(id)
  end

  def get_first_room! do
    Repo.one!(from r in Room, limit: 1, order_by: [asc: :name])
  end

  def list_rooms do
    Repo.all(from r in Room, order_by: [asc: :name])
  end
end

defmodule Slax.Chat.Room do
  use Ecto.Schema
  import Ecto.Changeset

  schema "rooms" do
    field :name, :string
    field :topic, :string

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(room, attrs) do
    room
    |> cast(attrs, [:name, :topic])
    |> validate_required([:name, :topic])
  end
end
