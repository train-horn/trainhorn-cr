require "./trainhorn/validate"
require "./trainhorn/acoustics"
require "./trainhorn/air_system"
require "./trainhorn/electrical"

# Small, dependency-free calculators for train horn setups on trucks, cars
# and boats.
#
# `Trainhorn` is a Crystal port of the `trainhorn_calc` Python package (and
# its Go port). It uses the same formulas and constants, so all three give
# the same numbers. It covers three areas:
#
# * **Acoustics**: sound pressure level (SPL) versus distance from the
#   inverse-square law (`.spl_at_distance`, `.distance_for_spl`), the loss per
#   doubling of distance (`.doubling_loss`), adding the levels of several
#   horns (`.combine_levels`) and optional atmospheric absorption
#   (`AIR_ABSORPTION_DB_PER_KM`).
# * **Air system**: free air in a tank from Boyle's law
#   (`.free_air_volume_cu_ft`), continuous horn time (`.tank_runtime_seconds`,
#   `.blast_count`) and compressor refill time
#   (`.compressor_recovery_seconds`, `.compressor_recovery_linear_seconds`).
# * **Electrical**: copper AWG resistance computed from the AWG definition
#   (`.awg_resistance_ohm_per_1000ft`), round-trip voltage drop
#   (`.voltage_drop`) and the smallest gauge that meets a voltage-drop budget
#   (`.suggest_awg`).
#
# ```
# require "trainhorn"
#
# Trainhorn.spl_at_distance(150.0, 100.0, 10.0)           # => 130.0
# Trainhorn.tank_runtime_seconds(5.0, 150.0, 110.0, 10.0) # => 10.915668...
# Trainhorn.suggest_awg(30.0, 10.0, 12.0).awg             # => "6"
# ```
#
# Every function validates its input and raises `Trainhorn::InvalidInputError`
# (a subclass of `ArgumentError`) instead of returning a meaningless number.
#
# Results are engineering estimates from simple models (free field,
# isothermal expansion, voltage drop only). They are not measurements and not
# a legal noise assessment, and `.suggest_awg` does not check ampacity or fuse
# sizing. Browser versions of these formulas are available as
# [interactive calculators](https://train-horn.com/tools/).
module Trainhorn
  # The shard version.
  VERSION = "1.0.0"
end
