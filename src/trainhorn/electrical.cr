module Trainhorn
  # The resistivity of annealed copper (100 % IACS) at 20 degC in ohm-metres.
  COPPER_RESISTIVITY_OHM_M = 1.7241e-8

  # The temperature coefficient of resistance of annealed copper near 20 degC.
  COPPER_TEMP_COEFF_PER_C = 0.00393

  # The gauges `.suggest_awg` considers, thinnest to thickest: the sizes
  # commonly sold as automotive primary wire and battery cable. Odd sizes
  # still work in the other methods.
  AWG_SIZES = {"18", "16", "14", "12", "10", "8", "6", "4", "2", "1", "1/0", "2/0", "3/0", "4/0"}

  # "Aught" labels and their formula index.
  private AUGHT = {"1/0" => 0, "0" => 0, "2/0" => -1, "00" => -1, "3/0" => -2, "000" => -2, "4/0" => -3, "0000" => -3}

  # Maps an AWG label to its formula index (1/0 -> 0, 4/0 -> -3).
  protected def self.awg_number(awg : String) : Int32
    text = awg.strip.upcase.gsub("AWG", "").strip
    if n = AUGHT[text]?
      return n
    end
    n = text.to_i? || raise InvalidInputError.new("unknown AWG size #{awg.inspect}; use 1-40 or 1/0..4/0")
    raise InvalidInputError.new("AWG size must be between 4/0 and 40, got #{awg.inspect}") unless 1 <= n <= 40
    n
  end

  # Returns the bare conductor diameter in millimetres of a solid AWG size,
  # from the ASTM B258 definition `d(n) = 0.005 in * 92^((36-n)/39)`. *awg* is
  # a label such as `"10"`, `"10 AWG"`, `"1/0"` or `"0000"`.
  def self.awg_diameter_mm(awg : String) : Float64
    n = awg_number(awg)
    0.127 * 92.0 ** ((36 - n) / 39.0) # 0.005 in = 0.127 mm
  end

  # Returns the conductor cross-section area in mm^2 of a solid AWG size.
  def self.awg_area_mm2(awg : String) : Float64
    d = awg_diameter_mm(awg)
    Math::PI * d * d / 4.0
  end

  # Returns the copper resistance in ohms per 1000 ft at *temperature_c*
  # (-60 to 200 degC; 20 gives the table value). It is computed as
  # `R = rho*L/A` with a linear temperature correction
  # `R_T = R_20 * (1 + 0.00393*(T - 20))`, and agrees with published solid
  # copper AWG tables to within about 1 %.
  def self.awg_resistance_ohm_per_1000ft(awg : String, temperature_c : Float64 = 20.0) : Float64
    check_number("temperature_c", temperature_c)
    unless -60 <= temperature_c <= 200
      raise InvalidInputError.new("temperature_c must be between -60 and 200 degC")
    end
    area = awg_area_mm2(awg)
    r20 = COPPER_RESISTIVITY_OHM_M * 304.8 / (area * 1e-6) # 1000 ft = 304.8 m
    r20 * (1.0 + COPPER_TEMP_COEFF_PER_C * (temperature_c - 20.0))
  end

  # Returns the voltage lost in a two-conductor copper run of
  # *one_way_length* (in *unit*) carrying *amps*:
  #
  # ```text
  # V_drop = amps * R_per_length * 2 * one_way_length
  # ```
  #
  # Current flows out and back, so the conductor length is twice the one-way
  # run.
  def self.voltage_drop(amps : Float64, one_way_length : Float64, awg : String,
                        unit : String = FEET, temperature_c : Float64 = 20.0) : Float64
    check_positive("amps", amps)
    check_positive("one_way_length", one_way_length)
    u = check_unit(unit)
    r = awg_resistance_ohm_per_1000ft(awg, temperature_c)
    feet = to_meters(one_way_length, u) / METERS_PER_FOOT
    amps * (r * (2.0 * feet) / 1000.0)
  end

  # The result of `Trainhorn.suggest_awg`.
  record WireSuggestion,
    # Suggested gauge label, e.g. `"6"` or `"1/0"`.
    awg : String,
    # Drop with that gauge, in volts.
    voltage_drop_v : Float64,
    # Drop as a percentage of `system_voltage`.
    voltage_drop_pct : Float64,
    # The budget that was requested, in percent.
    allowed_drop_pct : Float64,
    # Nominal system voltage.
    system_voltage : Float64,
    # Load current in amps.
    amps : Float64,
    # One-way run length in `unit`.
    one_way_length : Float64,
    # Unit of `one_way_length` (`"ft"` or `"m"`).
    unit : String

  # Returns the smallest copper gauge from `AWG_SIZES` whose round-trip
  # voltage drop stays within *max_drop_pct* (0 < x <= 50; 3 is a common
  # budget) of *system_voltage* (typically 12 or 24).
  #
  # It checks voltage drop only, not ampacity or fuse sizing; always size the
  # fuse to protect the wire you choose. Raises `InvalidInputError` if the
  # input is invalid or even 4/0 cannot meet the budget.
  #
  # ```
  # Trainhorn.suggest_awg(30.0, 10.0, 12.0).awg # => "6"
  # ```
  def self.suggest_awg(amps : Float64, one_way_length : Float64, system_voltage : Float64,
                       max_drop_pct : Float64 = 3.0, unit : String = FEET,
                       temperature_c : Float64 = 20.0) : WireSuggestion
    check_positive("amps", amps)
    check_positive("one_way_length", one_way_length)
    check_positive("system_voltage", system_voltage)
    check_positive("max_drop_pct", max_drop_pct)
    raise InvalidInputError.new("max_drop_pct must be 50 or less") if max_drop_pct > 50
    u = check_unit(unit)

    allowed_v = system_voltage * max_drop_pct / 100.0
    AWG_SIZES.each do |awg|
      drop = voltage_drop(amps, one_way_length, awg, u, temperature_c)
      if drop <= allowed_v
        return WireSuggestion.new(awg, drop, drop / system_voltage * 100.0, max_drop_pct,
          system_voltage, amps, one_way_length, u)
      end
    end
    raise InvalidInputError.new("no gauge up to 4/0 keeps the drop within #{max_drop_pct}% " \
                                "(#{amps} A over #{one_way_length} #{u}); shorten the run, raise the " \
                                "system voltage or use parallel conductors")
  end
end
