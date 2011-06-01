class Hash
  def require_keys(*valid_keys)
    missing_keys = [valid_keys].flatten - keys
    raise(ArgumentError, "Missing some required keys: #{missing_keys.join(", ")}") unless missing_keys.empty?
  end
end
