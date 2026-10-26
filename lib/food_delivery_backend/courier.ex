defmodule FoodDeliveryBackend.Courier do
  @moduledoc """
  A courier who can be assigned to deliveries.

  A courier has a name, a vehicle, and an availability flag. The flag is
  managed by `Fleet`: assigning a courier marks them busy, and completing
  or cancelling their delivery marks them available again. Validation
  lives in `new/1` so invalid couriers can never enter a `Fleet`.
  """

  @enforce_keys [:id, :name]
  defstruct [:id, :name, vehicle: :bike, available?: true]

  @type vehicle :: :bike | :scooter | :car

  @type t :: %__MODULE__{
          id: String.t(),
          name: String.t(),
          vehicle: vehicle(),
          available?: boolean()
        }

  @vehicles [:bike, :scooter, :car]

  @doc """
  Builds a courier from attributes.

  Returns `{:ok, courier}` or `{:error, reason}`. `:name` must be a
  non-blank string; `:vehicle`, when given, must be one of
  `:bike`, `:scooter` or `:car` (default `:bike`); `:available?`, when
  given, must be a boolean.
  """
  @spec new(map()) :: {:ok, t()} | {:error, String.t()}
  def new(attrs) when is_map(attrs) do
    with {:ok, name} <- required_string(attrs, :name),
         {:ok, vehicle} <- optional_vehicle(attrs),
         {:ok, available?} <- optional_boolean(attrs, :available?, true) do
      {:ok,
       %__MODULE__{
         id: Map.get(attrs, :id, ""),
         name: name,
         vehicle: vehicle,
         available?: available?
       }}
    end
  end

  @doc "True when the courier can take a new delivery."
  @spec available?(t()) :: boolean()
  def available?(%__MODULE__{} = courier), do: courier.available?

  defp required_string(attrs, key) do
    case Map.get(attrs, key) do
      value when is_binary(value) ->
        if String.trim(value) == "" do
          {:error, "#{key} must not be blank"}
        else
          {:ok, value}
        end

      _ ->
        {:error, "#{key} is required and must be a string"}
    end
  end

  defp optional_vehicle(attrs) do
    case Map.get(attrs, :vehicle, :bike) do
      vehicle when vehicle in @vehicles -> {:ok, vehicle}
      _ -> {:error, ":vehicle must be one of :bike, :scooter, :car"}
    end
  end

  defp optional_boolean(attrs, key, default) do
    case Map.get(attrs, key, default) do
      value when is_boolean(value) -> {:ok, value}
      _ -> {:error, "#{key} must be a boolean"}
    end
  end
end
