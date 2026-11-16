default:
    @just --list

# Render the fidget in several layouts: separate parts at the clearance, fused when overlapped, and the refusals
test:
    python3 tests/test_fidget.py

# Render the README picture into assets/
images:
    @mkdir -p assets
    openscad --camera=0,0,12,40,0,25,230 --imgsize=800,520 --colorscheme=Tomorrow -o assets/fidget.png planetary_gear_fidget.scad
