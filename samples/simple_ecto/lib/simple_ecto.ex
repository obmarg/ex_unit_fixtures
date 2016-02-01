defmodule SimpleEcto.Repo do
  use Ecto.Repo, otp_app: :simple_ecto
end

defmodule Weather do
  use Ecto.Schema
  schema "weather" do
    belongs_to :city, City
    field :wdate, Ecto.Date
    field :temp_lo, :integer
    field :temp_hi, :integer
    field :prcp, :float, default: 0.0
    timestamps
  end
end

defmodule City do
  use Ecto.Schema
  schema "cities" do
    has_many :local_weather, Weather
    belongs_to :country, Country
    field :name, :string
  end
end

defmodule Country do
  use Ecto.Schema
  schema "countries" do
    has_many :cities, City
    # here we associate the `:local_weather` from every City that belongs_to
    # a Country through that Country's `has_many :cities, City` association
    has_many :weather, through: [:cities, :local_weather]
    field :name, :string
  end
end
