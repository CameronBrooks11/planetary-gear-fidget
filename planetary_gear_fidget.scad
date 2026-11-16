// Planetary gear fidget: a print-in-place planetary gear set of herringbone gears, a sun, a ring
// and its planets, rounded into a disc. Printed as one part, it comes off the bed already
// assembled and turns. MIT licence; see LICENSE.

/* [Size] */

// Outer diameter of the ring gear, which is the fidget's diameter, mm
outerRingDiameter = 90;

// Thickness of every gear, mm
gearThickness = 25;

/* [Gears] */

// Number of planet gears
planetGearCount = 6;

// Teeth on each planet
planetGearTeethCount = 7;

// Teeth on the sun, roughly: the nearest count that lets the planets sit evenly is used
approxSunGearTeethCount = 14;

// Pressure angle, degrees. High angles give stubby, strong teeth that print well
pressureAngle = 42;

// How many teeth each half of a herringbone twists across
twistTeethCount = 1;

// Addendum, the tooth height above the pitch circle, in modules
maxToothDepthRatio = 0.9;

/* [Fit] */

// Gap between the parts where they mesh, mm. Every part is shrunk by half of it
clearanceTolerance = 0.15;

// Width across flats of a hexagonal hole through the sun, mm; 0 for none
hexHoleWidth = 1;

/* [Rounding] */

// Outer diameter of the torus that rounds the disc's rim, mm
outerTorusDiameter = 93;

// Diameter of that torus's tube, mm; more than gearThickness rounds the rim
torusThickness = 36;

/* [Hidden] */

// "all", or one part: "sun", "planets" or "ring"
part = "all";

$fn = $preview ? 48 : 96;

// ----- the gear set -----

planet_count = round(planetGearCount);
planet_teeth = round(planetGearTeethCount);

// The sun's teeth: the count nearest the request for which sun + ring is a multiple of the planet
// count, the condition for planets spaced evenly round the sun to mesh with both.
function sun_teeth(approx, zp, n) =
  let (
    candidates = [for (z = [max(3, round(approx) - n):round(approx) + n]) if ((2 * z + 2 * zp) % n == 0) z],
    distance = [for (z = candidates) abs(z - approx)]
  )
  assert(len(candidates) > 0, str("no sun tooth count near ", approx, " suits ", n, " planets"))
  candidates[search(min(distance), distance)[0]];

sun_teeth_count = sun_teeth(approxSunGearTeethCount, planet_teeth, planet_count);
ring_teeth_count = sun_teeth_count + 2 * planet_teeth;

// Dedendum beyond the addendum, in modules: room for the mating tip.
root_clearance = 0.25;

// Module: the ring's tooth roots sit at 85 % of its diameter, leaving 7.5 % each side as its rim.
gear_module = 0.85 * outerRingDiameter / (ring_teeth_count + 2 * (maxToothDepthRatio + root_clearance));

// Distance from the sun's centre to each planet's.
planet_orbit = gear_module * (sun_teeth_count + planet_teeth) / 2;

// ----- involute teeth -----

function deg(radians) = radians * 180 / PI;
// The involute function of a pressure angle in degrees, in radians.
function inv(a) = tan(a) - a * PI / 180;

// Polar angle, in degrees, of the flank of a tooth centred on angle 0, at radius r. rp is the
// pitch radius, rb the base radius, half the tooth's half-thickness at the pitch circle in radians.
function flank_angle(rp, rb, half, r) = deg(half + inv(acos(rb / rp)) - inv(acos(rb / max(r, rb))));

// The radius where the two flanks meet and the tooth comes to a point.
function pointed_radius(rp, rb, half, lo, hi, n = 40) =
  n == 0 ? lo
  : let (mid = (lo + hi) / 2)
    flank_angle(rp, rb, half, mid) > 0 ? pointed_radius(rp, rb, half, mid, hi, n - 1)
    : pointed_radius(rp, rb, half, lo, mid, n - 1);

// The outline of an external spur gear, counter-clockwise, a tooth centred on angle 0.
function gear_outline(z, m, pa, addendum, dedendum, steps = 8) =
  let (
    rp = m * z / 2,
    rb = rp * cos(pa),
    half = PI / (2 * z),
    tip = min(rp + addendum, pointed_radius(rp, rb, half, rb, 2 * rp) - 0.05 * m),
    root = max(0.1 * m, rp - dedendum),
    flank_start = max(root, rb),
    radii = [for (i = [0:steps]) flank_start + (tip - flank_start) * i / steps],
    base = flank_angle(rp, rb, half, flank_start)
  )
  [
    for (k = [0:z - 1]) let (c = 360 * k / z) each concat(
      [[root * cos(c - base), root * sin(c - base)]],
      [for (r = radii) let (a = c - flank_angle(rp, rb, half, r)) [r * cos(a), r * sin(a)]],
      [for (r = [for (i = [len(radii) - 1:-1:0]) radii[i]]) let (a = c + flank_angle(rp, rb, half, r)) [r * cos(a), r * sin(a)]],
      [[root * cos(c + base), root * sin(c + base)]]
    ),
  ];

// A herringbone extrusion of its 2D child: each half twists by twistTeethCount teeth of a gear
// with z teeth, the halves in opposite directions; hand is +1 or -1.
module herringbone(z, hand, h) {
  twist = hand * twistTeethCount * 360 / z;
  for (s = [0, 1])
    mirror([0, 0, s])
      linear_extrude(height=h / 2, twist=twist, slices=max(2, ceil(abs(twist) / 3)), convexity=4)
        children();
}

function frac(x) = x - floor(x);

module sun() {
  difference() {
    herringbone(sun_teeth_count, 1, gearThickness)
      offset(delta=-clearanceTolerance / 2)
        polygon(gear_outline(sun_teeth_count, gear_module, pressureAngle, maxToothDepthRatio * gear_module, (maxToothDepthRatio + root_clearance) * gear_module));
    if (hexHoleWidth > 0)
      cylinder(r=hexHoleWidth / sqrt(3), h=gearThickness + 2, center=true, $fn=6);
  }
}

// Planet i's direction from the centre, and its spin so that a sun tooth meets a planet gap.
function planet_direction(i) = 360 * i / planet_count;
function planet_spin(i) =
  let (phi = planet_direction(i), u = frac(phi * sun_teeth_count / 360))
  phi + 180 + (u + 0.5) * 360 / planet_teeth;

module planets() {
  for (i = [0:planet_count - 1])
    rotate(planet_direction(i))
      translate([planet_orbit, 0, 0])
        rotate(planet_spin(i) - planet_direction(i))
          herringbone(planet_teeth, -1, gearThickness)
            offset(delta=-clearanceTolerance / 2)
              polygon(gear_outline(planet_teeth, gear_module, pressureAngle, maxToothDepthRatio * gear_module, (maxToothDepthRatio + root_clearance) * gear_module));
}

// The ring's spin, set so that planet 0's tooth facing outward sits in a ring tooth space.
ring_spin =
  let (w = frac((0 - planet_spin(0)) * planet_teeth / 360))
  -w * 360 / ring_teeth_count;

module ring() {
  difference() {
    cylinder(d=outerRingDiameter, h=gearThickness, center=true);
    // The tooth spaces are an external gear's teeth, a root clearance deeper, grown by the gap.
    rotate(ring_spin)
      herringbone(ring_teeth_count, -1, gearThickness + 0.02)
        offset(delta=clearanceTolerance / 2)
          polygon(gear_outline(ring_teeth_count, gear_module, pressureAngle, (maxToothDepthRatio + root_clearance) * gear_module, maxToothDepthRatio * gear_module));
  }
}

// The disc's rounded rim: the hull of a torus whose outer diameter is outerTorusDiameter.
module rounding() {
  hull()
    rotate_extrude()
      translate([outerTorusDiameter / 2 - torusThickness / 2, 0])
        circle(d=torusThickness);
}

module planetary_gear_fidget() {
  assert(planet_count >= 2, "planetGearCount has to be at least 2");
  assert(planet_teeth >= 5, "planetGearTeethCount has to be at least 5");
  assert(torusThickness / 2 < outerTorusDiameter / 2, "torusThickness has to be less than outerTorusDiameter");
  // Neighbouring planets must clear each other's tips.
  assert(
    2 * planet_orbit * sin(180 / planet_count) > gear_module * (planet_teeth + 2 * maxToothDepthRatio) + clearanceTolerance,
    str(planet_count, " planets of ", planet_teeth, " teeth overlap each other: use fewer, or fewer teeth")
  );
  echo(sun_teeth=sun_teeth_count, ring_teeth=ring_teeth_count, gear_module=gear_module);

  translate([0, 0, gearThickness / 2])
    intersection() {
      union() {
        if (part == "all" || part == "sun") sun();
        if (part == "all" || part == "planets") planets();
        if (part == "all" || part == "ring") ring();
      }
      rounding();
    }
}

planetary_gear_fidget();
