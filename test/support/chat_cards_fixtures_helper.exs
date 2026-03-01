defmodule JsonLiveviewRenderTest.Companion.ChatCards.Catalog do
  use JsonLiveviewRender.Catalog

  component :card do
    description("Card container")
    prop(:title, :string, required: true)
  end

  component :status_badge do
    description("Status badge")
    prop(:severity, :string, required: true)
    prop(:label, :string, required: true)
  end

  component :text do
    description("Body text")
    prop(:content, :string, required: true)
  end

  component :data_row do
    description("Label-value row")
    prop(:label, :string, required: true)
    prop(:value, :string, required: true)
  end

  component :actions do
    description("Button collection")
  end

  component :button do
    description("Action button")
    prop(:id, :string, required: true)
    prop(:label, :string, required: true)
    prop(:style, :string)
  end

  component :mystery_widget do
    description("Unknown bridge component for fallback tests")
    prop(:note, :string, required: true)
  end

  component :admin_only do
    description("Admin content")
    prop(:message, :string, required: true)
    permission(:admin)
  end
end

defmodule JsonLiveviewRenderTest.Companion.ChatCards.Authorizer do
  @behaviour JsonLiveviewRender.Authorizer

  @impl true
  def allowed?(current_user, required_role) when is_map(current_user) do
    role = Map.get(current_user, :role)
    role == required_role or role == :admin
  end
end

defmodule JsonLiveviewRenderTest.Companion.ChatCards.SuccessSender do
  @behaviour JsonLiveviewRender.Companion.ChatCards.Sender

  @impl true
  def deliver(target, _payload, _context), do: {:ok, {:delivered, target}}
end

defmodule JsonLiveviewRenderTest.Companion.ChatCards.MixedSender do
  @behaviour JsonLiveviewRender.Companion.ChatCards.Sender

  @impl true
  def deliver(:slack, _payload, _context), do: {:ok, :sent}
  def deliver(:teams, _payload, _context), do: {:error, :timeout}
  def deliver(:whatsapp, _payload, _context), do: {:ok, :sent}
end
