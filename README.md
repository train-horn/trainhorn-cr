# trainhorn

Small, dependency-free Crystal calculators for train horn setups on trucks,
cars and boats. It is a port of the tested `trainhorn_calc` Python package
(and its Go port) and uses the same formulas and constants, so all of them
give the same numbers.

- **Acoustics**: SPL at a distance (inverse-square law, optional
  atmospheric absorption), the inverse (distance for a target level), loss
  per doubling of distance, and adding the levels of several horns.
- **Air system**: free air in a tank from Boyle's law, continuous horn
  runtime, whole blasts per tank, and compressor recovery time (constant or
  linear flow curve).
- **Electrical**: copper AWG diameter, area and resistance from the AWG
  definition, round-trip voltage drop, and the smallest gauge that meets a
  voltage-drop budget.

Every method validates its input and raises `Trainhorn::InvalidInputError`
(an `ArgumentError`) instead of returning a meaningless number.

## Installation

Add the dependency to your `shard.yml`:

```yaml
dependencies:
  trainhorn:
    github: train-horn/trainhorn-cr
    version: ~> 1.0
```

Then run `shards install`.

## Usage

```crystal
require "trainhorn"

# A 150 dB horn rated at 10 ft, heard 100 ft away (free field).
Trainhorn.spl_at_distance(150.0, 100.0, 10.0)              # => 130.0

# Same, in metres, with 1.9 dB/km air absorption (500 Hz band).
Trainhorn.spl_at_distance(150.0, 800.0, 10.0, "m", 1.9)

# Where does it fall to 90 dB?
Trainhorn.distance_for_spl(150.0, 90.0, 10.0)              # => 10000.0 (ft)

Trainhorn.doubling_loss                                    # => 6.020599913279624
Trainhorn.combine_levels(100.0, 100.0)                     # => 103.01029995663981

# 5 gal tank, 150 -> 110 psi, horn uses 10 CFM.
Trainhorn.tank_runtime_seconds(5.0, 150.0, 110.0, 10.0)    # => 10.91566866267465
Trainhorn.blast_count(10.9, 2.0)                           # => 5

# Refill a 2 gal tank from 110 to 150 psi at 1.0 CFM.
Trainhorn.compressor_recovery_seconds(2.0, 110.0, 150.0, 1.0) # => 43.662674650698605

# 30 A compressor, 10 ft one-way run, 12 V, 3 % drop budget.
s = Trainhorn.suggest_awg(30.0, 10.0, 12.0, 3.0)
s.awg              # => "6"
s.voltage_drop_pct # => 1.9753226951012177
```

Pressures are gauge psi. Lengths take a unit, `"ft"` (default) or `"m"`.

## Limits

These are engineering estimates from simple models (free field, isothermal
expansion, voltage drop only). They are not measurements and not a legal
noise assessment. `suggest_awg` does not check ampacity or fuse sizing;
always fuse to protect the wire you choose.

Browser versions of the same formulas: [train horn calculators](https://train-horn.com/tools/).

## Development

```sh
crystal spec   # 60 examples; reference vectors from the Python core within 1e-9
crystal docs   # API docs in ./docs
```

## License

MIT, see [LICENSE](LICENSE).
