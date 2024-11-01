defmodule Slax.Chat do
  alias Slax.Chat.Room
  alias Slax.Repo

  def get_room!(id) do
   Room |> Repo.get!(id)
  end

  def get_first_room! do
    [room | _] = list_rooms()
    room
  end

  def list_rooms do
    Room |> Repo.all()
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
