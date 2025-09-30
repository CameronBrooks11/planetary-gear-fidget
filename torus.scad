// Define torus shape module
module torusShape() {
  rotate_extrude(angle=360, $fn=180)
    translate([innerTorusDiameter / 3, 12, 0])
      circle(r=torusThickness / 2, $fn=60);
}
