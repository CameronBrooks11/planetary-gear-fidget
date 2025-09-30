// Define herringbone gear module
module herringboneGear(teethCount = 15, pitch = 10, angle = 28, depthRatio = 1, clearance = 0, helixAngle = 0, thickness = 5) {
  union() {
    gear(teethCount, pitch, angle, depthRatio, clearance, helixAngle, thickness / 2);
    mirror([0, 0, 1]) gear(teethCount, pitch, angle, depthRatio, clearance, helixAngle, thickness / 2);
  }
}

// Define gear module
module gear(teethCount = 15, pitch = 10, angle = 28, depthRatio = 1, clearance = 0, helixAngle = 0, thickness = 5, isFlat = false) {
  pitchRadius = teethCount * pitch / (2 * PI);
  twistAngle = tan(helixAngle) * thickness / pitchRadius * 180 / PI;

  flatExtrude(height=thickness, twist=twistAngle, isFlat=isFlat) {
    gear2D(teethCount, pitch, angle, depthRatio, clearance);
  }
}

// Define flat extrusion module
module flatExtrude(height, twist, isFlat) {
  if (isFlat == false)
    linear_extrude(height=height, twist=twist, slices=twist / 6) children(0);
  else
    children(0);
}

// Define 2D gear profile module
module gear2D(teethCount, pitch, angle, depthRatio, clearance) {
  pitchRadius = teethCount * pitch / (2 * PI);
  baseRadius = pitchRadius * cos(angle);
  toothDepth = pitch / (2 * tan(angle));
  outerRadius = clearance < 0 ? pitchRadius + toothDepth / 2 - clearance : pitchRadius + toothDepth / 2;
  rootRadius = max(baseRadius, pitchRadius - toothDepth / 2 - clearance / 2);
  backlashAngle = clearance / (pitchRadius * cos(angle)) * 180 / PI;
  halfToothAngle = 90 / teethCount - backlashAngle / 2;
  pitchPoint = involute(baseRadius, involuteIntersectAngle(baseRadius, pitchRadius));
  pitchAngle = atan2(pitchPoint[1], pitchPoint[0]);

  intersection() {
    rotate(90 / teethCount)
      circle($fn=teethCount * 3, r=pitchRadius + depthRatio * pitch / 2 - clearance / 2);

    union() {
      rotate(90 / teethCount)
        circle($fn=teethCount * 2, r=max(rootRadius, pitchRadius - depthRatio * pitch / 2 - clearance / 2));

      for (i = [1:teethCount]) {
        rotate(i * 360 / teethCount) {
          halfTooth(pitchAngle, baseRadius, rootRadius, outerRadius, halfToothAngle);
          mirror([0, 1]) halfTooth(pitchAngle, baseRadius, rootRadius, outerRadius, halfToothAngle);
        }
      }
    }
  }
}

// Define half tooth module
module halfTooth(pitchAngle, baseRadius, rootRadius, outerRadius, halfToothAngle) {
  index = [0, 1, 2, 3, 4, 5];
  startAngle = max(involuteIntersectAngle(baseRadius, rootRadius) - 5, 0);
  stopAngle = involuteIntersectAngle(baseRadius, outerRadius);
  angle = index * (stopAngle - startAngle) / (index[len(index) - 1]);

  points = [
    [0, 0],
    involute(baseRadius, angle[0] + startAngle),
    involute(baseRadius, angle[1] + startAngle),
    involute(baseRadius, angle[2] + startAngle),
    involute(baseRadius, angle[3] + startAngle),
    involute(baseRadius, angle[4] + startAngle),
    involute(baseRadius, angle[5] + startAngle),
  ];

  difference() {
    rotate(-pitchAngle - halfToothAngle) polygon(points=points);
    square(2 * outerRadius);
  }
}

// Involute and angle calculations
function involuteIntersectAngle(baseRadius, radius) = sqrt(pow(radius / baseRadius, 2) - 1) * 180 / PI;
function involute(baseRadius, involuteAngle) =
  [
    baseRadius * (cos(involuteAngle) + involuteAngle * PI / 180 * sin(involuteAngle)),
    baseRadius * (sin(involuteAngle) - involuteAngle * PI / 180 * cos(involuteAngle)),
  ];
