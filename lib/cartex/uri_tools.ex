defmodule URITools do
  @exclusion_prefix "__do_not_www_form_encode__"

  def escape_next_substring(query, excluding, reverse_replacements) when excluding == [] do
    {query, reverse_replacements}
  end

  def escape_next_substring(query, excluding, reverse_replacements) do
    [substring | tail] = excluding
    replacement = "#{@exclusion_prefix}_#{length(reverse_replacements)}"

    escape_next_substring(String.replace(query, substring, replacement), tail, [{replacement, substring} | reverse_replacements])  
  end

  def unescape_next_substring(query, reverse_replacements) when reverse_replacements == [] do
    query
  end

  def unescape_next_substring(query, reverse_replacements) do
    [{substring, replacement} | tail] = reverse_replacements

    unescape_next_substring(String.replace(query, substring, replacement), tail)  
  end

  def encode_www_form(query, excluding \\ []) do
    {query, reverse_replacements} = escape_next_substring(query, excluding, [])
    unescape_next_substring(URI.encode_www_form(query), reverse_replacements)
  end
end

