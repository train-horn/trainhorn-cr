module Trainhorn
  # Raised by every `Trainhorn` method for an invalid argument (a non-finite
  # number, a value out of range, an unknown unit or wire size). It is an
  # `ArgumentError`, so `rescue ArgumentError` catches it too.
  class InvalidInputError < ArgumentError
  end

  # Length unit: feet.
  FEET = "ft"

  # Length unit: metres.
  METERS = "m"

  # The exact length of one international foot in metres.
  METERS_PER_FOOT = 0.3048

  # Raises `InvalidInputError` unless *value* is finite; returns *value*.
  protected def self.check_number(name : String, value : Float64) : Float64
    raise InvalidInputError.new("#{name} must be finite, got #{value}") if value.nan? || value.infinite?
    value
  end

  # Raises `InvalidInputError` unless *value* is finite and greater than 0.
  protected def self.check_positive(name : String, value : Float64) : Float64
    check_number(name, value)
    raise InvalidInputError.new("#{name} must be greater than 0, got #{value}") unless value > 0
    value
  end

  # Raises `InvalidInputError` unless *value* is finite and 0 or greater.
  protected def self.check_non_negative(name : String, value : Float64) : Float64
    check_number(name, value)
    raise InvalidInputError.new("#{name} must be 0 or greater, got #{value}") if value < 0
    value
  end

  # Normalises a length unit ("ft" or "m", case and spaces ignored).
  protected def self.check_unit(unit : String) : String
    u = unit.strip.downcase
    raise InvalidInputError.new("unit must be one of ft, m; got #{unit.inspect}") unless u == FEET || u == METERS
    u
  end

  # Converts *value* in *unit* (already normalised) to metres.
  protected def self.to_meters(value : Float64, unit : String) : Float64
    unit == FEET ? value * METERS_PER_FOOT : value
  end
end
