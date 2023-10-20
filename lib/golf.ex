defmodule Golf do
  @moduledoc """
  Golf keeps the contexts that define your domain
  and business logic.

  Contexts are also responsible for managing your data, regardless
  if it comes from the database, an external API or others.
  """

  @inserted_at_format "%y/%m/%d %H:%m:%S"
  def inserted_at_format(), do: @inserted_at_format
end
