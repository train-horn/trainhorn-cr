require "spec"
require "../src/trainhorn"

# Expected values were produced by the reference Python package
# trainhorn_calc 1.0.0 (repr of each float); the port must match within TOL.
TOL = 1e-9

def near(got : Float64, want : Float64, eps : Float64 = TOL)
  (got - want).abs.should be <= eps
end

describe Trainhorn do
  it "has a version" do
    Trainhorn::VERSION.should eq "1.0.0"
  end

  describe ".spl_at_distance" do
    cases = [
      {150.0, 100.0, 10.0, "ft", 0.0, 130.0},
      {118.0, 10.0, 10.0, "ft", 0.0, 118.0},
      {150.0, 5.0, 10.0, "ft", 0.0, 156.02059991327963},
      {120.0, 10.0, 1.0, "m", 0.0, 100.0},
      {140.0, 300.0, 10.0, "ft", 0.0, 110.45757490560675},
      {140.0, 300.0, 10.0, "m", 0.0, 110.45757490560675},
      {150.0, 1010.0, 10.0, "m", 0.0, 109.91357252434715},
      {150.0, 1010.0, 10.0, "m", 2.0, 107.91357252434715},
      {150.0, 3290.84, 10.0, "ft", 0.0, 99.65386465010951},
      {150.0, 3290.84, 10.0, "ft", 10.0, 89.65386433010951},
      {150.0, 37.5, 10.0, "ft", 0.0, 138.51937464544562},
      {153.2, 2500.0, 10.0, "ft", 0.0, 105.24119982655924},
      {150.0, 3.0, 10.0, "m", 3.7, 160.48347490560676},
      {150.0, 50.0, 10.0, "m", 3.7, 135.87259991327963},
      {150.0, 800.0, 10.0, "m", 3.7, 109.01520026016112},
      {150.0, 5000.0, 10.0, "m", 3.7, 77.55759991327963},
      {150.0, 1609.344, 10.0, "ft", 1.9, 104.9408101986925},
      {150.0, 100.0, 10.0, " FT ", 0.0, 130.0},
    ]
    cases.each do |(src, d, ref, unit, alpha, want)|
      it "gives #{want} for #{src} dB, #{d} #{unit.strip}, ref #{ref}, #{alpha} dB/km" do
        near Trainhorn.spl_at_distance(src, d, ref, unit, alpha), want
        near Trainhorn.spl_at_distance(src, d, ref), want if alpha == 0 && unit.strip.downcase == "ft"
      end
    end

    it "applies the absorption term in metres" do
      plain = Trainhorn.spl_at_distance(150.0, 1010.0, 10.0, "m", 0.0)
      absorbed = Trainhorn.spl_at_distance(150.0, 1010.0, 10.0, "m", 2.0)
      near plain - absorbed, 2.0
      plain = Trainhorn.spl_at_distance(150.0, 3290.84, 10.0, "ft", 0.0)
      absorbed = Trainhorn.spl_at_distance(150.0, 3290.84, 10.0, "ft", 10.0)
      near plain - absorbed, 10.0 * (3290.84 - 10) * 0.3048 / 1000
    end
  end

  describe ".distance_for_spl" do
    cases = [
      {150.0, 130.0, 10.0, "ft", 0.0, 100.0},
      {150.0, 90.0, 10.0, "ft", 0.0, 10000.0},
      {150.0, 90.0, 10.0, "ft", 1.9, 6491.256148481227},
      {150.0, 160.0, 10.0, "ft", 1.9, 3.163719354263083},
      {150.0, 100.0, 1.0, "m", 3.7, 280.7075555048921},
      {118.0, 98.0, 10.0, "ft", 0.0, 100.0},
    ]
    cases.each do |(src, target, ref, unit, alpha, want)|
      it "gives #{want} #{unit} for #{src} -> #{target} dB at #{alpha} dB/km" do
        near Trainhorn.distance_for_spl(src, target, ref, unit, alpha), want, TOL * {1.0, want}.max
      end
    end

    it "round-trips with .spl_at_distance" do
      [{150.0, 37.5}, {118.0, 2.0}, {153.2, 2500.0}, {100.0, 10.0}].each do |(src, d)|
        target = Trainhorn.spl_at_distance(src, d, 10.0)
        near Trainhorn.distance_for_spl(src, target, 10.0), d, 1e-6
      end
      [3.0, 50.0, 800.0, 5000.0].each do |d|
        target = Trainhorn.spl_at_distance(150.0, d, 10.0, "m", 3.7)
        near Trainhorn.distance_for_spl(150.0, target, 10.0, "m", 3.7), d, d * 1e-9
      end
    end

    it "is shortened by absorption" do
      Trainhorn.distance_for_spl(150.0, 90.0, 10.0, "ft", 1.9).should be < Trainhorn.distance_for_spl(150.0, 90.0, 10.0)
    end
  end

  describe "losses and level addition" do
    it "computes the doubling loss" do
      near Trainhorn.doubling_loss, 6.020599913279624
    end

    it "computes the distance ratio loss" do
      near Trainhorn.distance_ratio_loss(10.0), 20.0
    end

    it "combines incoherent levels" do
      near Trainhorn.combine_levels(100.0, 100.0), 103.01029995663981
      near Trainhorn.combine_levels(150.0), 150.0
      near Trainhorn.combine_levels([120.0, 90.0]), 120.00434077479319
      near Trainhorn.combine_levels([150.0, 150.0, 150.0]), 154.77121254719663
    end
  end

  describe "acoustics input validation" do
    it "raises ArgumentError" do
      expect_raises(ArgumentError) { Trainhorn.spl_at_distance(150.0, 0.0, 10.0) }
      expect_raises(ArgumentError) { Trainhorn.spl_at_distance(150.0, -5.0, 10.0) }
      expect_raises(ArgumentError) { Trainhorn.spl_at_distance(150.0, 10.0, 0.0) }
      expect_raises(ArgumentError) { Trainhorn.spl_at_distance(150.0, 10.0, 10.0, "yd") }
      expect_raises(ArgumentError) { Trainhorn.spl_at_distance(Float64::NAN, 10.0, 10.0) }
      expect_raises(ArgumentError) { Trainhorn.spl_at_distance(Float64::INFINITY, 10.0, 10.0) }
      expect_raises(ArgumentError) { Trainhorn.spl_at_distance(150.0, 10.0, 10.0, "ft", -1.0) }
      expect_raises(ArgumentError) { Trainhorn.combine_levels([] of Float64) }
      expect_raises(ArgumentError) { Trainhorn.combine_levels(100.0, Float64::NAN) }
      expect_raises(ArgumentError) { Trainhorn.distance_ratio_loss(0.0) }
      expect_raises(Trainhorn::InvalidInputError, /too far apart/) { Trainhorn.distance_for_spl(150.0, -1e6, 10.0) }
    end
  end

  describe "air system" do
    it "computes free air from Boyle's law" do
      near Trainhorn.free_air_volume_cu_ft(1.0, 14.696, 0.0), 0.13368055555555555
      near Trainhorn.free_air_volume_cu_ft(5.0, 150.0, 110.0, Trainhorn::ATMOSPHERIC_PSI), 1.8192781104457751
    end

    it "computes tank runtime" do
      near Trainhorn.tank_runtime_seconds(5.0, 150.0, 110.0, 10.0, 14.696), 10.91566866267465
      near Trainhorn.tank_runtime_seconds(2.0, 150.0, 120.0, 5.0, 14.696), 6.549401197604791
      near Trainhorn.tank_runtime_seconds(5.0, 150.0, 110.0, 10.0, 12.2), 13.148907103825138
      base = Trainhorn.tank_runtime_seconds(2.0, 150.0, 120.0, 5.0)
      near Trainhorn.tank_runtime_seconds(4.0, 150.0, 120.0, 5.0), 2 * base
    end

    it "counts whole blasts" do
      Trainhorn.blast_count(10.0, 2.0).should eq 5
      Trainhorn.blast_count(10.9, 2.0).should eq 5
      Trainhorn.blast_count(0.0, 1.5).should eq 0
      Trainhorn.blast_count(0.3 * 3, 0.3).should eq 3
    end

    it "computes compressor recovery" do
      near Trainhorn.compressor_recovery_seconds(2.0, 110.0, 150.0, 1.0), 43.662674650698605
      got = Trainhorn.compressor_recovery_seconds(3.0, 120.0, 150.0, 2.5)
      near got, 19.64820359281437
      near got, Trainhorn.tank_runtime_seconds(3.0, 150.0, 120.0, 2.5)
    end

    it "computes compressor recovery with a linear flow curve" do
      near Trainhorn.compressor_recovery_linear_seconds(2.0, 110.0, 150.0, 1.0, 1.0, 150.0), 43.662674650698605
      lin = Trainhorn.compressor_recovery_linear_seconds(2.0, 110.0, 150.0, 1.0, 2.0, 150.0)
      near lin, 38.70512365385508
      # Closed form vs. numeric integration (midpoint rule).
      v = 2 * 231.0 / 1728 / 14.696
      steps = 20000
      dp = 40.0 / steps
      numeric = (0...steps).sum { |i| v * dp / (2.0 - (110 + (i + 0.5) * dp) / 150) }
      near lin, numeric * 60, 1e-4
    end

    it "raises ArgumentError on invalid input" do
      atm = Trainhorn::ATMOSPHERIC_PSI
      expect_raises(ArgumentError) { Trainhorn.tank_runtime_seconds(0.0, 150.0, 110.0, 10.0) }
      expect_raises(ArgumentError) { Trainhorn.tank_runtime_seconds(5.0, 110.0, 150.0, 10.0) }
      expect_raises(ArgumentError) { Trainhorn.tank_runtime_seconds(5.0, 150.0, 150.0, 10.0) }
      expect_raises(ArgumentError) { Trainhorn.tank_runtime_seconds(5.0, 150.0, -1.0, 10.0) }
      expect_raises(ArgumentError) { Trainhorn.tank_runtime_seconds(5.0, 150.0, 110.0, 0.0) }
      expect_raises(ArgumentError) { Trainhorn.free_air_volume_cu_ft(5.0, 150.0, 110.0, 0.0) }
      expect_raises(ArgumentError) { Trainhorn.compressor_recovery_seconds(2.0, 150.0, 110.0, 1.0, atm) }
      expect_raises(ArgumentError) { Trainhorn.compressor_recovery_linear_seconds(2.0, 110.0, 150.0, 1.0, 0.5, 150.0) }
      expect_raises(ArgumentError) { Trainhorn.compressor_recovery_linear_seconds(2.0, 110.0, 150.0, 0.1, 5.0, 100.0) }
      expect_raises(ArgumentError) { Trainhorn.compressor_recovery_linear_seconds(2.0, 110.0, 150.0, 1.0, 2.0, 0.0) }
      expect_raises(ArgumentError) { Trainhorn.blast_count(10.0, 0.0) }
      expect_raises(ArgumentError) { Trainhorn.blast_count(-1.0, 1.0) }
    end
  end

  describe "AWG" do
    cases = [
      {"18", 1.0236873428326523, 0.8230468337313146, 6.384881861674867},
      {"14", 1.627726633791505, 2.080907717098377, 2.5253675388006465},
      {"12", 2.052525388493948, 3.3087728761114765, 1.5882192573386384},
      {"10", 2.5881867280128636, 5.261154954510373, 0.9988409095411369},
      {"8", 3.2636432058836333, 8.365564060081022, 0.6281772229892056},
      {"7", 3.6648500338805654, 10.548781512773461, 0.49816718581541203},
      {"6", 4.11537809850691, 13.301767890969138, 0.3950645390202436},
      {"4", 5.189395968020595, 21.15063942544283, 0.24845853093587858},
      {"1/0", 8.251462802171464, 53.47512073211765, 0.09827106003790216},
      {"4/0", 11.684000000000001, 107.21930257703055, 0.049012227030898296},
    ]
    cases.each do |(awg, diam, area, r)|
      it "gives diameter, area and resistance for #{awg} AWG" do
        near Trainhorn.awg_diameter_mm(awg), diam
        near Trainhorn.awg_area_mm2(awg), area
        near Trainhorn.awg_resistance_ohm_per_1000ft(awg, 20.0), r
      end
    end

    it "agrees with published solid-copper tables within 1 %" do
      {"14" => 2.525, "12" => 1.588, "10" => 0.9989, "8" => 0.6282, "4" => 0.2485, "1/0" => 0.09827}.each do |awg, want|
        near Trainhorn.awg_resistance_ohm_per_1000ft(awg), want, want * 0.01
      end
      near Trainhorn.awg_area_mm2("7") / Trainhorn.awg_area_mm2("10"), 2.0, 0.01
    end

    it "accepts label aliases" do
      [{"1/0", "0"}, {"4/0", "0000"}, {"10", "10 AWG"}, {"2/0", " 00 "}, {"6", "6awg"}].each do |(a, b)|
        Trainhorn.awg_diameter_mm(b).should eq Trainhorn.awg_diameter_mm(a)
      end
    end

    it "corrects resistance for temperature" do
      near Trainhorn.awg_resistance_ohm_per_1000ft("10", 70.0), 1.1951131482659703
      near Trainhorn.awg_resistance_ohm_per_1000ft("4", -20.0), 0.20940084987275848
    end
  end

  describe ".voltage_drop" do
    it "computes the round-trip drop" do
      near Trainhorn.voltage_drop(20.0, 10.0, "10", "ft", 20.0), 0.39953636381645474
      near Trainhorn.voltage_drop(20.0, 3.048, "10", "m", 20.0), 0.39953636381645474
      near Trainhorn.voltage_drop(30.0, 10.0, "6"), 0.23703872341214613
    end
  end

  describe ".suggest_awg" do
    cases = [
      {30.0, 10.0, 12.0, 3.0, "6", 0.23703872341214613, 1.9753226951012177},
      {30.0, 10.0, 24.0, 3.0, "10", 0.5993045457246821, 2.4971022738528417},
      {5.0, 3.0, 12.0, 3.0, "18", 0.191546455850246, 1.5962204654187166},
      {15.0, 20.0, 12.0, 3.0, "6", 0.23703872341214613, 1.9753226951012177},
      {40.0, 6.0, 24.0, 3.0, "10", 0.47944363657974565, 1.9976818190822736},
      {100.0, 15.0, 12.0, 3.0, "1/0", 0.2948131801137065, 2.456776500947554},
      {30.0, 10.0, 24.0, 2.0, "8", 0.3769063337935234, 1.570443057473014},
    ]
    cases.each do |(amps, length, volts, max_pct, awg, drop_v, drop_pct)|
      it "suggests #{awg} AWG for #{amps} A over #{length} ft at #{volts} V, #{max_pct} %" do
        s = Trainhorn.suggest_awg(amps, length, volts, max_pct, "ft", 20.0)
        s.awg.should eq awg
        near s.voltage_drop_v, drop_v
        near s.voltage_drop_pct, drop_pct
        s.voltage_drop_pct.should be <= max_pct
        s.unit.should eq "ft"
        s.allowed_drop_pct.should eq max_pct
        # Minimal: the next thinner gauge must exceed the budget.
        i = Trainhorn::AWG_SIZES.index!(awg)
        if i > 0
          thinner = Trainhorn.voltage_drop(amps, length, Trainhorn::AWG_SIZES[i - 1], "ft", 20.0)
          (thinner / volts * 100).should be > max_pct
        end
      end
    end
  end

  describe "electrical input validation" do
    it "raises ArgumentError" do
      ["5/0", "abc", "-1", "41", "", "0.5"].each do |bad|
        expect_raises(ArgumentError) { Trainhorn.awg_diameter_mm(bad) }
      end
      expect_raises(ArgumentError) { Trainhorn.suggest_awg(0.0, 10.0, 12.0) }
      expect_raises(ArgumentError) { Trainhorn.suggest_awg(10.0, 10.0, 12.0, 0.0) }
      expect_raises(ArgumentError) { Trainhorn.suggest_awg(10.0, 10.0, 12.0, 60.0) }
      expect_raises(ArgumentError) { Trainhorn.suggest_awg(10.0, 10.0, -12.0) }
      expect_raises(ArgumentError) { Trainhorn.suggest_awg(1000.0, 200.0, 12.0) }
      expect_raises(ArgumentError) { Trainhorn.awg_resistance_ohm_per_1000ft("10", 500.0) }
      expect_raises(ArgumentError) { Trainhorn.voltage_drop(10.0, 10.0, "10", "yd") }
    end
  end
end
