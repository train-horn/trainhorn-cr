module Trainhorn
  # The standard atmosphere at sea level in psi. Pass a lower value for
  # altitude to the air-system methods.
  ATMOSPHERIC_PSI = 14.696

  # The volume of one US liquid gallon in cubic feet (231 in^3 / 1728 in^3).
  CUBIC_FEET_PER_GALLON = 231.0 / 1728.0

  # Validates a high/low gauge-pressure pair.
  protected def self.check_pressures(high_name : String, high : Float64, low_name : String, low : Float64) : Nil
    check_non_negative(high_name, high)
    check_non_negative(low_name, low)
    unless high > low
      raise InvalidInputError.new("#{high_name} (#{high} psi) must be greater than #{low_name} (#{low} psi)")
    end
  end

  # Free air between two pressures, with validation.
  protected def self.free_air(tank_gallons : Float64, high_name : String, high : Float64,
                              low_name : String, low : Float64, atmospheric_psi : Float64) : Float64
    check_positive("tank_gallons", tank_gallons)
    check_pressures(high_name, high, low_name, low)
    check_positive("atmospheric_psi", atmospheric_psi)
    tank_gallons * CUBIC_FEET_PER_GALLON * (high - low) / atmospheric_psi
  end

  # Returns the free air (cubic feet at atmospheric pressure) released while
  # a tank drops from *start_psi* to *end_psi*, from Boyle's law:
  #
  # ```text
  # V_free = tank_gallons * 0.13368 * (start_psi - end_psi) / atmospheric_psi
  # ```
  #
  # Pressures are gauge psi (as read on a dial); *start_psi* must be greater
  # than *end_psi* and *end_psi* >= 0.
  def self.free_air_volume_cu_ft(tank_gallons : Float64, start_psi : Float64, end_psi : Float64,
                                 atmospheric_psi : Float64 = ATMOSPHERIC_PSI) : Float64
    free_air(tank_gallons, "start_psi", start_psi, "end_psi", end_psi, atmospheric_psi)
  end

  # Returns the seconds of continuous horn time from a tank at *start_psi*
  # down to *cutoff_psi* (the lowest gauge pressure at which the horn still
  # sounds acceptably) for a horn consuming *horn_cfm* of free air:
  #
  # ```text
  # t = free_air_volume_cu_ft(...) / horn_cfm * 60
  # ```
  #
  # The model assumes isothermal expansion, a constant horn consumption and
  # the compressor off while the horn sounds, so treat the result as an upper
  # estimate.
  #
  # ```
  # Trainhorn.tank_runtime_seconds(5.0, 150.0, 110.0, 10.0) # => 10.91566866267465
  # ```
  def self.tank_runtime_seconds(tank_gallons : Float64, start_psi : Float64, cutoff_psi : Float64,
                                horn_cfm : Float64, atmospheric_psi : Float64 = ATMOSPHERIC_PSI) : Float64
    check_positive("horn_cfm", horn_cfm)
    free_air(tank_gallons, "start_psi", start_psi, "cutoff_psi", cutoff_psi, atmospheric_psi) / horn_cfm * 60.0
  end

  # Returns how many whole blasts of *blast_seconds* fit in
  # *runtime_seconds*. A tiny epsilon keeps exact divisions such as 10/2 from
  # being lost to floating-point rounding.
  def self.blast_count(runtime_seconds : Float64, blast_seconds : Float64) : Int32
    check_non_negative("runtime_seconds", runtime_seconds)
    check_positive("blast_seconds", blast_seconds)
    (runtime_seconds / blast_seconds + 1e-9).floor.to_i
  end

  # Returns the seconds a compressor needs to refill a tank from *cut_in_psi*
  # to *cut_out_psi*, assuming it delivers a constant *compressor_cfm* of free
  # air over the whole range:
  #
  # ```text
  # t = V_free / compressor_cfm * 60
  # ```
  #
  # Use the CFM the manufacturer rates at (or near) your cut-out pressure;
  # output falls as pressure rises, so a 0 psi rating gives an optimistic
  # time.
  def self.compressor_recovery_seconds(tank_gallons : Float64, cut_in_psi : Float64, cut_out_psi : Float64,
                                       compressor_cfm : Float64, atmospheric_psi : Float64 = ATMOSPHERIC_PSI) : Float64
    check_positive("compressor_cfm", compressor_cfm)
    free_air(tank_gallons, "cut_out_psi", cut_out_psi, "cut_in_psi", cut_in_psi, atmospheric_psi) / compressor_cfm * 60.0
  end

  # `.compressor_recovery_seconds` with a linear flow curve: delivery falls
  # linearly from *cfm_at_zero_psi* at 0 psi to *compressor_cfm* at
  # *rated_psi*, `q(p) = a + b*p`. Integrating `dt = (V_tank / P_atm) dp / q(p)`
  # gives
  #
  # ```text
  # t = V_tank / P_atm * ln(q(cut_out) / q(cut_in)) / b * 60    (b != 0)
  # ```
  #
  # *cfm_at_zero_psi* must be at least *compressor_cfm*, *rated_psi* must be
  # > 0, and the curve must still deliver air at *cut_out_psi*. A flat curve
  # (*cfm_at_zero_psi* == *compressor_cfm*) gives the constant-flow result.
  def self.compressor_recovery_linear_seconds(tank_gallons : Float64, cut_in_psi : Float64, cut_out_psi : Float64,
                                              compressor_cfm : Float64, cfm_at_zero_psi : Float64, rated_psi : Float64,
                                              atmospheric_psi : Float64 = ATMOSPHERIC_PSI) : Float64
    check_positive("compressor_cfm", compressor_cfm)
    v = free_air(tank_gallons, "cut_out_psi", cut_out_psi, "cut_in_psi", cut_in_psi, atmospheric_psi)
    q0 = check_positive("cfm_at_zero_psi", cfm_at_zero_psi)
    p_rated = check_positive("rated_psi", rated_psi)
    if q0 < compressor_cfm
      raise InvalidInputError.new("cfm_at_zero_psi must be at least compressor_cfm (output falls with pressure)")
    end
    slope = (compressor_cfm - q0) / p_rated # cfm per psi, <= 0
    q_in = q0 + slope * cut_in_psi
    q_out = q0 + slope * cut_out_psi
    if q_out <= 0
      raise InvalidInputError.new("the linear flow model gives no output at #{cut_out_psi} psi; check cfm_at_zero_psi, compressor_cfm and rated_psi")
    end
    return v / q0 * 60.0 if slope == 0
    tank_cu_ft = tank_gallons * CUBIC_FEET_PER_GALLON
    tank_cu_ft / atmospheric_psi * Math.log(q_out / q_in) / slope * 60.0
  end
end
