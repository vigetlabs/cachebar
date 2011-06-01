class Hash
  def require_keys(*valid_keys)
    unknown_keys = keys - [valid_keys].flatten
    raise(ArgumentError, "Unknown key(s): #{unknown_keys.join(", ")}") unless unknown_keys.empty?
    
    missing_keys = [valid_keys].flatten - keys
    raise(ArgumentError, "Missing some required keys: #{missing_keys.join(", ")}") unless missing_keys.empty?
  end
end
