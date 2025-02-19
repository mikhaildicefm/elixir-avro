defmodule ElixirAvro.AvroType.Value.Decoder do
  @moduledoc """
  Module responsible for decoding values from Avro type definition.
  """

  alias ElixirAvro.AvroType
  alias ElixirAvro.AvroType.Array
  alias ElixirAvro.AvroType.Primitive
  alias ElixirAvro.AvroType.Union
  alias ElixirAvro.Template.Names

  alias Noether.Either

  @doc ~S"""
  Decodes any avro value into its elixir format; raise if an error occurs.

  # Examples

  ## Primitive types

  iex> decode_value!(nil, %Primitive{name: "null"}, "")
  nil

  iex> decode_value!(true, %Primitive{name: "boolean"}, "")
  true

  iex> decode_value!(25, %Primitive{name: "int"}, "")
  25

  iex> decode_value!(2_147_483_648, %Primitive{name: "int"}, "")
  ** (ArgumentError) decoding error: value out of range

  iex> decode_value!(19723, %Primitive{name: "int", custom_props: [%CustomProp{name: "logicalType", value: "date"}]}, "")
  ~D[2024-01-01]

  iex> decode_value!(3661123, %Primitive{name: "int", custom_props: [%CustomProp{name: "logicalType", value: "time-millis"}]}, "")
  ~T[01:01:01.123]

  iex> decode_value!(202.35, %Primitive{name: "int", custom_props: [%CustomProp{name: "logicalType", value: "date"}]}, "")
  ** (ArgumentError) decoding error: not an integer value

  iex> decode_value!(25699000123, %Primitive{name: "long", custom_props: [%CustomProp{name: "logicalType", value: "time-micros"}]}, "")
  ~T[07:08:19.000123]

  iex> decode_value!(1704070923000, %Primitive{name: "long", custom_props: [%CustomProp{name: "logicalType", value: "timestamp-millis"}]}, "")
  ~U[2024-01-01 01:02:03.000Z]

  iex> decode_value!(1263423607005000, %Primitive{name: "long", custom_props: [%CustomProp{name: "logicalType", value: "local-timestamp-micros"}]}, "")
  ~N[2010-01-13 23:00:07.005000]

  iex> decode_value!("2024-01-13 11:00:03.123", %Primitive{name: "long", custom_props: [%CustomProp{name: "logicalType", value: "timestamp-micros"}]}, "")
  ** (ArgumentError) decoding error: not an integer value

  iex> decode_value!("67caff17-798d-4b70-b9d0-781d27382fdc", %Primitive{name: "string", custom_props: [%CustomProp{name: "logicalType", value: "uuid"}]}, "")
  "67caff17-798d-4b70-b9d0-781d27382fdc"

  iex> decode_value!("not-a-uuid", %Primitive{name: "string", custom_props: [%CustomProp{name: "logicalType", value: "uuid"}]}, "")
  ** (ArgumentError) decoding error: not a uuid value

  ## Array types

  iex> decode_value!(["one", "two"], %Array{type:  %Primitive{name: "string"}}, "")
  ["one", "two"]

  iex> decode_value!(["one", 2], %Array{type:  %Primitive{name: "string"}}, "")
  ** (ArgumentError) decoding error: not a string value

  ## Map types

  iex> decode_value!(%{"one" => 1, "two" => 2}, %Map{type: %Primitive{name: "int"}}, "")
  %{"one" => 1, "two" => 2}

  iex> decode_value!(%{"one" => 1, "two" => "2"},  %Map{type: %Primitive{name: "int"}}, "")
  ** (ArgumentError) decoding error: not an integer value

  ## Union types

  iex> decode_value!(
  ...>  nil,
  ...>  %Union{values: %{
  ...>    0 => %Primitive{name: "null"},
  ...>    1 => %Primitive{name: "string", custom_props: [%CustomProp{name: "logicalType", value: "uuid"}]}
  ...>  }}, "")
  nil

  iex> decode_value!(
  ...>  "d8d8d536-700d-4773-a950-90fdcd3ae686",
  ...>  %Union{values: %{
  ...>    0 => %Primitive{name: "null"},
  ...>    1 => %Primitive{name: "string", custom_props: [%CustomProp{name: "logicalType", value: "uuid"}]}
  ...>  }}, "")
  "d8d8d536-700d-4773-a950-90fdcd3ae686"

  iex> decode_value!(
  ...>  "not-a-uuid-or-nil",
  ...>  %Union{values: %{
  ...>    0 => %Primitive{name: "null"},
  ...>    1 => %Primitive{name: "string", custom_props: [%CustomProp{name: "logicalType", value: "uuid"}]}
  ...>  }}, "")
  ** (ArgumentError) decoding error: no compatible type found

  """
  @spec decode_value!(any(), AvroType.t(), String.t(), String.t() | nil) :: any() | no_return()
  def decode_value!(value, type, module_prefix, hint \\ nil) do
    case decode_value(value, type, module_prefix) do
      {:ok, value} -> value
      {:error, error} ->
        message = "decoding error: #{error}" <> if(hint, do: " #{hint}", else: "")
        raise ArgumentError, message
    end
  end

  @spec decode_value(any(), AvroType.t(), String.t()) :: {:ok, any()} | {:error, any()}
  defp decode_value(value, %Primitive{} = type, _), do: Primitive.decode(value, type)

  defp decode_value(values, %Array{type: type}, module_prefix) when is_list(values) do
    values
    |> Enum.reduce_while({:ok, []}, fn value, {:ok, result} ->
      case decode_value(value, type, module_prefix) do
        {:ok, decoded} -> {:cont, {:ok, [decoded | result]}}
        error -> {:halt, error}
      end
    end)
    |> Either.map(&Enum.reverse/1)
  end

  defp decode_value(values, %AvroType.Map{type: type}, module_prefix) when is_map(values) do
    Enum.reduce_while(values, {:ok, %{}}, fn {key, value}, {:ok, result} ->
      case decode_value(value, type, module_prefix) do
        {:ok, decoded} -> {:cont, {:ok, Map.put(result, key, decoded)}}
        error -> {:halt, error}
      end
    end)
  end

  defp decode_value(value, %Union{values: union_values}, module_prefix) do
    error = {:error, "no compatible type found"}

    Enum.reduce_while(union_values, error, fn {_id, type}, res ->
      case decode_value(value, type, module_prefix) do
        {:ok, decoded} -> {:halt, {:ok, decoded}}
        _ -> {:cont, res}
      end
    end)
  end

  defp decode_value(value, reference, module_prefix) when is_binary(reference) do
    module = reference |> Names.module_name!(module_prefix) |> String.to_atom()

    Code.ensure_loaded(module)

    if function_exported?(module, :from_avro, 1) do
      module.from_avro(value)
    else
      {:error, "unknown reference: #{reference}"}
    end
  end
end
