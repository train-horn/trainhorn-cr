module Trainhorn
  # Approximate atmospheric absorption in dB/km at 10 degC and 70 % relative
  # humidity (an ISO 9613-2 Table 2 condition, computed from the ISO 9613-1
  # equations). Keys are octave-band centre frequencies in Hz. Train horn
  # chords sit mostly between about 250 Hz and 600 Hz, where absorption is
  # only 1-2 dB/km, so it matters only at long range. Treat the values as a
  # rough guide.
  AIR_ABSORPTION_DB_PER_KM = {
      63 => 0.1,
     125 => 0.4,
     250 => 1.0,
     500 => 1.9,
    1000 => 3.7,
    2000 => 9.7,
    4000 => 32.8,
    8000 => 117.0,
  }

  # Estimates the sound pressure level at *distance* from a level *source_db*
  # known at *ref_distance*, using the free-field inverse-square law plus an
  # optional atmospheric absorption term on the path beyond *ref_distance*:
  #
  # ```text
  # L = source_db - 20*log10(d/d_ref) - absorption_db_per_km*(d_m - d_ref_m)/1000
  # ```
  #
  # Both distances are in *unit* (`"ft"` or `"m"`) and must be greater than 0.
  # Horn ratings are commonly quoted "at 10 ft" or "at 1 m"; pass that as
  # *ref_distance*. *absorption_db_per_km* must be >= 0; see
  # `AIR_ABSORPTION_DB_PER_KM`. The model assumes a point source in open air
  # with no reflections, wind or barriers, so real outdoor levels can differ
  # by several dB.
  #
  # ```
  # Trainhorn.spl_at_distance(150.0, 100.0, 10.0) # => 130.0
  # ```
  def self.spl_at_distance(source_db : Float64, distance : Float64, ref_distance : Float64,
                           unit : String = FEET, absorption_db_per_km : Float64 = 0.0) : Float64
    check_number("source_db", source_db)
    check_positive("distance", distance)
    check_positive("ref_distance", ref_distance)
    u = check_unit(unit)
    check_non_negative("absorption_db_per_km", absorption_db_per_km)
    spl_unchecked(source_db, distance, ref_distance, u, absorption_db_per_km)
  end

  # Level at *distance* without validation (used by the bisection solver).
  protected def self.spl_unchecked(source_db : Float64, distance : Float64, ref_distance : Float64,
                                   unit : String, alpha : Float64) : Float64
    level = source_db - 20.0 * Math.log10(distance / ref_distance)
    level -= alpha * (to_meters(distance, unit) - to_meters(ref_distance, unit)) / 1000.0 if alpha != 0
    level
  end

  # Returns the distance at which the level falls to *target_db*; the inverse
  # of `.spl_at_distance`. Without absorption it is the closed form
  #
  # ```text
  # d = ref_distance * 10^((source_db - target_db)/20)
  # ```
  #
  # With absorption there is no elementary closed form, so it is solved by
  # bisection between the free-field answer and *ref_distance*. *target_db*
  # may be higher than *source_db*, giving a distance closer than
  # *ref_distance*. The result is in *unit*.
  def self.distance_for_spl(source_db : Float64, target_db : Float64, ref_distance : Float64,
                            unit : String = FEET, absorption_db_per_km : Float64 = 0.0) : Float64
    check_number("source_db", source_db)
    check_number("target_db", target_db)
    check_positive("ref_distance", ref_distance)
    u = check_unit(unit)
    check_non_negative("absorption_db_per_km", absorption_db_per_km)

    free_field = ref_distance * 10.0 ** ((source_db - target_db) / 20.0)
    if free_field == 0 || free_field.infinite?
      raise InvalidInputError.new("source_db and target_db are too far apart to give a usable distance")
    end
    return free_field if absorption_db_per_km == 0 || free_field == ref_distance

    # Absorption lowers the level beyond ref_distance and raises it inside it,
    # so the root lies between the free-field answer and ref_distance.
    lo, hi = {free_field, ref_distance}.min, {free_field, ref_distance}.max
    200.times do
      mid = 0.5 * (lo + hi)
      if spl_unchecked(source_db, mid, ref_distance, u, absorption_db_per_km) - target_db > 0
        lo = mid
      else
        hi = mid
      end
      break if hi - lo <= 1e-12 * hi
    end
    0.5 * (lo + hi)
  end

  # Returns the free-field level change in dB when the distance is multiplied
  # by *ratio*: `20*log10(ratio)`. A ratio of 10 gives 20 dB. *ratio* must be
  # greater than 0.
  def self.distance_ratio_loss(ratio : Float64) : Float64
    check_positive("ratio", ratio)
    20.0 * Math.log10(ratio)
  end

  # Returns the free-field loss for each doubling of distance,
  # `20*log10(2)`, about 6.02 dB.
  def self.doubling_loss : Float64
    20.0 * Math.log10(2.0)
  end

  # Adds the levels of incoherent sources (for example two horns sounding
  # together) into one level:
  #
  # ```text
  # L = 10*log10(sum(10^(Li/10)))
  # ```
  #
  # Two equal sources add about 3.01 dB; they do not double the decibels. At
  # least one level is required.
  #
  # ```
  # Trainhorn.combine_levels([100.0, 100.0]) # => 103.01029995663981
  # ```
  def self.combine_levels(levels_db : Enumerable(Float64)) : Float64
    levels = levels_db.to_a
    raise InvalidInputError.new("combine_levels needs at least one level") if levels.empty?
    levels.each { |v| check_number("level", v) }
    # Factor out the peak to avoid overflow with very large dB values.
    peak = levels.max
    sum = levels.sum { |v| 10.0 ** ((v - peak) / 10.0) }
    peak + 10.0 * Math.log10(sum)
  end

  # Same as `.combine_levels(Enumerable)`, taking the levels as arguments.
  def self.combine_levels(*levels_db : Float64) : Float64
    combine_levels(levels_db.to_a)
  end
end
