Path.wildcard("test/support/**/*.{ex,exs}")
|> Enum.each(&Code.require_file/1)

ExUnit.start()
