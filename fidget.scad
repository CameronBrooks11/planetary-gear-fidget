// Planetary Gear Fidget Toy

use <gears.scad>
use <torus.scad>

// Outer diameter of the ring gear in millimeters
outerRingDiameter = 90;

// Thickness of all gears in millimeters
gearThickness = 25;

// Clearance tolerance to prevent gear interference
clearanceTolerance = 0.15;

// Total number of planet gears in the system
planetGearCount = 6;

// Number of teeth on each planet gear
planetGearTeethCount = 7;

// Approximate number of teeth on the sun gear (initial estimate)
approxSunGearTeethCount = 14;

// Pressure angle in degrees, affects gear strength and smoothness
pressureAngle = 42;

// Number of teeth contributing to the twist in herringbone gears
twistTeethCount = 1;

// Width of the hexagonal hole in the center of the sun gear
hexHoleWidth = 1;

// Maximum ratio of tooth depth relative to gear dimensions
maxToothDepthRatio = 0.9;

// Outer diameter of the torus (donut shape) in millimeters
outerTorusDiameter = 122;

// Thickness of the torus in millimeters
torusThickness = 36;

module fidget() {

  // Calculated variables
  planetCount = round(planetGearCount);
  planetTeethCount = round(planetGearTeethCount);
  sunGearTeethCount = approxSunGearTeethCount;
  kFactor = round(2 / planetCount * (sunGearTeethCount + planetTeethCount));
  kFactorAdjusted = (kFactor * planetCount % 2 != 0) ? kFactor + 1 : kFactor;
  actualSunGearTeethCount = kFactorAdjusted * planetCount / 2 - planetTeethCount;
  ringGearTeethCount = actualSunGearTeethCount + 2 * planetTeethCount;
  pitchDiameter = 0.9 * outerRingDiameter / (1 + min(PI / (2 * ringGearTeethCount * tan(pressureAngle)), PI * maxToothDepthRatio / ringGearTeethCount));
  gearPitch = pitchDiameter * PI / ringGearTeethCount;
  calculatedHelixAngle = atan(2 * twistTeethCount * gearPitch / gearThickness);
  rotationAngle = $t * 360 / planetCount;
  innerTorusDiameter = outerTorusDiameter - torusThickness;

  echo("Sun Gear Teeth (actualSunGearTeethCount): ", actualSunGearTeethCount);
  echo("Gear Pitch: ", gearPitch);
  echo("Helix Angle: ", calculatedHelixAngle);

  // Main structure with intersection and translation
  // Planetary Gear intersection with torus shape
  intersection() {
    translate([0, 0, gearThickness / 2]) {
      difference() {
        cylinder(r=outerRingDiameter, h=gearThickness, center=true, $fn=100); // Outer ring gear

        // Herringbone for the ring gear
        herringboneGear(ringGearTeethCount, gearPitch, pressureAngle, maxToothDepthRatio, -clearanceTolerance, calculatedHelixAngle, gearThickness + 0.2);

        difference() {
          translate([0, -outerRingDiameter / 2, 0])
            rotate([90, 0, 0]){}
          cylinder(r=outerRingDiameter / 2 - 0.25, h=gearThickness + 2, center=true, $fn=100);
        }
      }

      rotate([0, 0, (planetTeethCount + 1) * 180 / actualSunGearTeethCount + rotationAngle * (actualSunGearTeethCount + planetTeethCount) * 2 / actualSunGearTeethCount]) {
        difference() {
          mirror([0, 1, 0]) herringboneGear(actualSunGearTeethCount, gearPitch, pressureAngle, maxToothDepthRatio, clearanceTolerance, calculatedHelixAngle, gearThickness);
          cylinder(r=hexHoleWidth / sqrt(3), h=gearThickness + 1, center=true, $fn=6);
        }
      }

      // Planet Gears
      for (i = [1:planetCount]) {
        rotate([0, 0, i * 360 / planetCount + rotationAngle])
          translate([pitchDiameter / 2 * (actualSunGearTeethCount + planetTeethCount) / ringGearTeethCount, 0, 0])
            rotate([0, 0, i * actualSunGearTeethCount / planetCount * 360 / planetTeethCount - rotationAngle * (actualSunGearTeethCount + planetTeethCount) / planetTeethCount - rotationAngle]) {
              herringboneGear(planetTeethCount, gearPitch, pressureAngle, maxToothDepthRatio, clearanceTolerance, calculatedHelixAngle, gearThickness);
            }
      }
    }

    // Torus/donut shape
    torusShape();
  }
}

fidget();
