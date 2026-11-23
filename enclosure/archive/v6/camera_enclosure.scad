// Living-room camera enclosure - parametric OpenSCAD model (v6: tower with a hidden eye).
//
// A slim upright tower with a flat back, flat sides near the back and a rounded
// front, so it hangs flat on a wall, sits into a left or right corner, or stands on
// a cupboard (in the optional foot).
// The top part (hood) continues the same shape, so from outside it reads as one
// object; the only feature is a small dark dome in a round port, which looks like
// the motion sensor of an alarm system.
//   - tower: the battery stands against the back plate; side ribs, a shelf below,
//     ledges above and two front ribs (on a foam pad) hold it. Below it the TP4056
//     stands up with its USB-C opening in the bottom face, next to the switch lever.
//   - hood: print it dark. The eye is a dark 22 mm ball with the camera inside; it
//     sticks out 3.5 mm so the lens stays in front of the hood wall when turned,
//     and the port round it flares at 45 degrees - the picture is not cut until the
//     eye points about 44 degrees away from straight ahead (e.g. 30 to the side and
//     30 down). A lip holds it from the front, a clamp ring with two screws from
//     behind (they set the friction). Aim it by pushing the dome with a fingertip.
//     The 75 mm camera flex lets it turn while the XIAO stays put on the side wall.
//   - wedges (optional): angle the whole tower 20 or 30 degrees off the wall, e.g.
//     to face the middle of the room from near a corner; the top one carries two
//     pegs for the keyholes, the bottom one is a spacer.
//   - back plate: full height, closes tower and hood; two keyholes (nail, screw,
//     picture hook) and a flat face for adhesive strips.
// The XIAO's LEDs must stay off in the firmware, or they glow through the port.
//
// Pick what to show/export with `part`, then Render (F6) and export STL.
// Print in PETG or ASA, 0.2 mm layers, 3 walls. Tower upright, hood upside down,
// back plate flat (wall side down), eye with a little support under it, clamp and
// foot flat, wedges on their wall side.
//
// Hardware: 4x M3x8 (back plate) + 2x M3x10 (clamp ring), self-tapping (wedges:
// 2 wall screws each, or adhesive strips); soft
// silicone wire 26-28 AWG; 1.5-2 mm foam tape; double-sided foam tape for the XIAO.

part = "assembly";  // [assembly, inside, exploded, section, tower, hood, back, eye, clamp, foot, wedge_top, wedge_bottom, print_all]
eye_tilt = 25;      // preview: degrees the eye looks down (0..45)
eye_pan = 0;        // preview: degrees the eye is turned to the left (-45..45)
wedge = 30;         // wedge angle (20 or 30); the preview uses it when show_wedge
show_wedge = false;
show_parts = true;
show_foot = true;

/* [Contents - measured] */
batt = [61, 14, 110];     // battery: width, thickness, height (incl. the sealed edge)
foam = 1.5;
side_clear = 1.5;
tp = [18.5, 25, 1.6];     // TP4056: width, length (USB end down), PCB
tp_usb_h = 3.2;
sw = [9, 3.5, 3];         // switch: length, body width, body height (lever points down)
xiao = [21, 17.8, 8];     // XIAO + Sense: height, width, stack thickness

/* [Shell] */
wall = 2.2;
pt = 3;                   // back plate thickness (its back face is the wall side)
fit = 0.3;
flat = 18.5;              // flat part of each side, from the back
bulge = 9;                // the rounded front sticks out this far beyond the flats
bot_h = 29;               // bottom compartment: battery shelf top
top_h = 16;               // above the battery (keyholes)
hood_h = 40;

/* [Openings] */
usb_w = 9.6;  usb_h = 4.0;
plug_w = 12.5; plug_h = 7;
switch_slot = [5.5, 2.2];

/* [Eye] */
ball_r = 11;
eye_out = 3.5;            // how far the dome sticks out of the hood front
eye_up = 19;              // ball centre above the hood bottom
lip_at = 75;              // the front lip grips the ball this many degrees off its axis
cam_sq = 8.5;
cam_sq_d = 4.2;
cam_len = 12.4;
lens_bore = 10.4;         // lens measured 10 mm
lens_recess = 0.5;

/* [Screws] */
pilot_d = 2.5;
screw_d = 3.4;

$fn = 48;

// ---------- derived ----------
W = batt.x + 2 * side_clear + 2 * wall;
D = flat + bulge;
H = bot_h + batt.z + 1 + top_h;       // tower height
Ht = H + hood_h;                      // overall height
eye_y = D + eye_out - ball_r;         // ball centre from the back plate front face
ec = [0, eye_y, H + eye_up];          // ball centre
lip_y = ball_r * cos(lip_at);         // lip plane, in front of the centre
lip_r = ball_r * sin(lip_at) - 0.1;
tp_x0 = -24; tp_x1 = tp_x0 + tp.x;
tp_y = 8;
usb_y = tp_y + tp.z + tp_usb_h / 2;
sw_x = 15;
kh_z = H - 10;
bp_screws = [for (s = [-1, 1], z = [14, Ht - 6]) [s * (W / 2 - wall - 3.1), z]];

// ---------- profile ----------
// Seen from above: x across, y away from the wall (0 = back plate front face).
module prof(o = 0) {
    offset(r = o) union() {
        offset(r = 2) offset(delta = -2) translate([-W / 2, 0]) square([W, flat]);
        translate([0, flat]) scale([W / 2, bulge]) circle(1, $fn = 120);
        translate([-W / 2, flat - 3]) square([W, 3]);
    }
}
module outline(o = 0) { offset(r = o) union() { prof(); translate([-W / 2, -pt]) offset(r = 2) offset(delta = -2) square([W, pt + 3]); } }
module slot(w, h, depth) {
    hull() for (x = [-(w - h) / 2, (w - h) / 2]) translate([x, 0, 0]) cylinder(d = h, h = depth);
}

// ---------- tower ----------
module tower() {
    difference() {
        union() {
            difference() {
                linear_extrude(H) prof();
                translate([0, 0, wall]) linear_extrude(H) prof(-wall);
                translate([-W / 2 + wall, -1, wall]) cube([W - 2 * wall, wall + 1.01, H]);   // open back
            }
            for (s = [-1, 1]) {
                // battery shelf below and ledges above (45-degree undersides)
                translate([s * (W / 2 - wall - 2.5), batt.y / 2, bot_h - 1]) hull() {
                    cube([5, batt.y, 2], center = true);
                    translate([s * 2.49, 0, -2.5]) cube([0.01, batt.y, 2], center = true);
                }
                translate([s * (W / 2 - wall - 2), batt.y / 2, bot_h + batt.z + 1 + 0.75]) hull() {
                    cube([4, batt.y, 1.5], center = true);
                    translate([s * 1.99, 0, -2.5]) cube([0.01, batt.y, 1.5], center = true);
                }
                for (z = [bot_h + 20, bot_h + batt.z - 20])
                    translate([s * (W / 2 - wall), batt.y / 2, z]) rotate([0, 0, s > 0 ? 90 : -90])
                        linear_extrude(30, center = true) polygon([[-2, -0.01], [2, -0.01], [0.6, 1], [-0.6, 1]]);
                // front rib: from the inside of the front down to the foam on the battery
                intersection() {
                    translate([s * 22 - 1.2, batt.y + foam, bot_h]) cube([2.4, D, batt.z]);
                    linear_extrude(H) prof(-wall + 0.01);
                }
                translate([s * (W / 2 - wall - 3.1), 3.1, 0]) cylinder(r = 3.4, h = 20);   // back plate screw boss
            }
            // TP4056 stands in two slotted posts, USB end down
            for (x = [tp_x0 + 0.5, tp_x1 - 0.5]) translate([x, tp_y + tp.z / 2, wall + 6]) difference() {
                cube([4, 5, 12], center = true);
                cube([5, tp.z + 0.3, 13], center = true);   // the PCB edge slides into this slot
            }
            // switch cradle on the floor, lever through the bottom
            translate([sw_x, usb_y, wall - 0.01]) difference() {
                translate([-sw.x / 2 - 1.4 - fit, -sw.y / 2 - 1.4 - fit, 0]) cube([sw.x + 2.8 + 2 * fit, sw.y + 2.8 + 2 * fit, sw.z]);
                translate([-sw.x / 2 - fit, -sw.y / 2 - fit, -1]) cube([sw.x + 2 * fit, sw.y + 2 * fit, sw.z + 2]);
            }
        }
        translate([(tp_x0 + tp_x1) / 2, usb_y, -1]) slot(usb_w, usb_h, wall + 2);
        translate([(tp_x0 + tp_x1) / 2, usb_y, -0.01]) slot(plug_w, plug_h, 1.01);
        translate([sw_x - switch_slot.x / 2, usb_y - switch_slot.y / 2, -1]) cube([switch_slot.x, switch_slot.y, wall + 2]);
        for (s = [-1, 1]) translate([s * (W / 2 - wall - 3.1), -1, 14]) rotate([-90, 0, 0]) cylinder(d = pilot_d, h = 9);
    }
}

// ---------- hood (in place, z from H) ----------
// Round port in front of the ball: starts at the lip and flares out at 45 degrees.
module port_cut() {
    translate([0, eye_y + lip_y, ec.z]) rotate([-90, 0, 0]) cylinder(r1 = lip_r, r2 = lip_r + 20, h = 20);
}
module hood() {
    difference() {
        union() {
            difference() {
                translate([0, 0, H]) linear_extrude(hood_h) prof();
                translate([0, 0, H - 1]) linear_extrude(hood_h - wall + 1) prof(-wall);
                translate([-W / 2 + wall, -1, H - 1]) cube([W - 2 * wall, wall + 1.01, hood_h - wall + 1]);   // open back
            }
            // plug into the tower's top opening (a frame, wires pass through the middle)
            translate([0, 0, H - 4]) linear_extrude(4.01) intersection() {
                difference() { prof(-wall - fit); prof(-wall - fit - 2); }
                translate([-W, 4.3]) square([2 * W, D]);
            }
            // seat block holding the ball from the front, with the lip
            intersection() {
                translate([-18, eye_y, ec.z - 16]) cube([36, D, 30]);
                translate([0, 0, H]) linear_extrude(hood_h) prof(-0.01);
            }
            // bosses for the back plate screws, hanging from the ceiling
            for (s = [-1, 1]) translate([s * (W / 2 - wall - 3.1), 3.1, Ht - 10]) cylinder(r = 3.4, h = 10);
        }
        translate([0, 0, ec.z]) sphere(r = ball_r + 0.15, $fn = 72);
        port_cut();
        // clamp ring screws
        for (s = [-1, 1]) translate([s * 14.5, eye_y - 1, ec.z - 7]) rotate([-90, 0, 0]) cylinder(d = pilot_d, h = 6);
        for (p = bp_screws) if (p[1] > H) translate([p[0], -1, p[1]]) rotate([-90, 0, 0]) cylinder(d = pilot_d, h = 9);
        // vents on top (the XIAO side gets air; the other side matches it)
        for (s = [-1, 1], i = [0 : 3]) translate([s * 22 - 1 + (i - 1.5) * 4.5, 15, Ht - wall - 1]) cube([2, 8, wall + 2]);
    }
}

// ---------- the eye (ball coordinates: centre at the origin, lens towards +y) ----------
module eye() {
    difference() {
        sphere(r = ball_r, $fn = 72);
        // lens hole from the front, square pocket for the holder from the back
        translate([0, ball_r - lens_recess - (cam_len - cam_sq_d) - 0.01, 0]) rotate([-90, 0, 0]) cylinder(d = lens_bore, h = ball_r);
        translate([-(cam_sq + 0.4) / 2, -ball_r - 1, -(cam_sq + 0.4) / 2]) cube([cam_sq + 0.4, ball_r + 1 + ball_r - lens_recess - (cam_len - cam_sq_d), cam_sq + 0.4]);
        // flex exit at the bottom of the pocket
        translate([-4, -ball_r - 1, -(cam_sq + 0.4) / 2 - 2]) cube([8, ball_r + 1 + ball_r - lens_recess - cam_len + 0.5, 3]);
        // two dimples beside the lens for a fingertip or a toothpick
        for (s = [-1, 1]) rotate([0, 0, s * 38]) translate([0, ball_r + 0.6, 0]) sphere(r = 1.6, $fn = 16);
    }
}

// Clamp ring behind the ball: its two screws set how stiffly the ball turns.
module clamp() {
    difference() {
        translate([-18, eye_y - 6.3, ec.z - 15]) cube([36, 6, 28]);
        translate([0, eye_y, ec.z]) sphere(r = ball_r + 0.15, $fn = 72);
        // the camera flex and the back of the ball come out through here
        translate([-7, eye_y - 7, ec.z - 9]) cube([14, 8, 14]);
        for (s = [-1, 1]) translate([s * 14.5, eye_y - 8, ec.z - 7]) rotate([-90, 0, 0]) {
            cylinder(d = screw_d, h = 10);
            cylinder(d = 6, h = 3.5);
        }
    }
}

// ---------- back plate (y from -pt to 0), full height ----------
module keyhole_cut() {
    translate([0, 0.01, 0]) rotate([90, 0, 0]) {
        cylinder(d = 8.5, h = pt + 1);
        translate([-2.1, 0, 0]) cube([4.2, 8, pt + 1]);
    }
}
module back() {
    difference() {
        union() {
            translate([-W / 2, -pt, 0]) rotate([90, 0, 0]) mirror([0, 0, 1])
                linear_extrude(pt) offset(r = 2) offset(delta = -2) square([W, Ht]);
            for (s = [-1, 1]) translate([s * 18 - 7, -0.01, kh_z - 6]) cube([14, 4, 15]);
        }
        for (s = [-1, 1]) translate([s * 18, 0, kh_z]) {
            keyhole_cut();
            translate([0, 4.5, 0]) rotate([90, 0, 0]) cylinder(d = 9, h = 4.5);
            translate([-4.5, 0, 0]) cube([9, 3.2, 9]);
        }
        for (p = bp_screws) translate([p[0], 1, p[1]]) rotate([90, 0, 0]) {
            cylinder(d = screw_d, h = pt + 2);
            translate([0, 0, 1 + pt - 1.7]) cylinder(d1 = screw_d, d2 = 6.4, h = 1.71);
        }
    }
}

// ---------- foot for a cupboard (optional) ----------
module foot() {
    difference() {
        linear_extrude(9) intersection() {
            offset(r = 16) outline();
            translate([-W, -pt]) square([2 * W, 3 * D]);
        }
        translate([0, 0, 3]) linear_extrude(7) outline(fit);
        for (s = [-1, 1]) translate([s * (W / 2 + 8), 8, 5]) scale([1, 1.6, 1]) cylinder(r = 9, h = 10);
    }
}

// ---------- wedges (wall coordinates: the wall is the plane y = -pt) ----------
// The tower turns about its right back edge; the thick end of the wedge is on the
// left, so the front turns to the right (towards the room, away from a corner on the
// left). Mirror it in the slicer for a corner on the right.
wedge_pivot = [W / 2, -pt];
module wedge_body(z0, h) {
    a = wedge;
    c = wedge_pivot + W * [-cos(a), sin(a)];
    translate([0, 0, z0]) linear_extrude(h) polygon([wedge_pivot, [-W / 2, -pt], c]);
}
// a point on the tower's back face, d along it from the pivot, pushed out by o
function on_face(d, o = 0) = wedge_pivot + d * [-cos(wedge), sin(wedge)] + o * [sin(wedge), cos(wedge)];
module wall_holes(z) {
    for (x = [-W / 2 + 12, -W / 2 + 34]) translate([x, -pt - 1, z]) rotate([-90, 0, 0]) {
        cylinder(d = 4.2, h = 60);
        translate([0, 0, 5]) cylinder(d = 8, h = 60);
    }
}
module wedge_top() {
    z0 = kh_z - 12;
    difference() {
        union() {
            wedge_body(z0, 30);
            // two pegs for the keyholes: neck, then a head that sits in the pocket
            for (k = [-1, 1]) {
                d = W / 2 + k * 18;
                translate([on_face(d).x, on_face(d).y, kh_z + 6]) rotate([0, 0, -wedge]) rotate([-90, 0, 0]) {
                    cylinder(d = 3.8, h = pt + 0.6);
                    translate([0, 0, pt + 0.6]) cylinder(d = 7.8, h = 2.4);
                }
            }
        }
        wall_holes(kh_z + 6);
    }
}
module wedge_bottom() {
    difference() { wedge_body(8, 30); wall_holes(23); }
}

// ---------- dummies (preview only) ----------
only = "";
function show(n) = only == "" || only == n;
module wire(pts, c) color(c) for (i = [0 : len(pts) - 2]) hull() {
    translate(pts[i]) sphere(d = 1.2, $fn = 8);
    translate(pts[i + 1]) sphere(d = 1.2, $fn = 8);
}
xiao_pos = [W / 2 - wall - xiao[2], 2.5, H + 3.5];   // on the right side wall, Sense side inwards
module tower_contents() {
    if (show("battery")) {
        color("RoyalBlue") translate([-batt.x / 2, 0.2, bot_h + 0.3]) cube([batt.x, batt.y - 0.4, batt.z]);
        color("Silver") for (x = [-12, 8]) translate([x, batt.y / 2, bot_h - 3]) cube([5, 0.3, 3.4]);
    }
    if (show("foam")) color("LightYellow") translate([-batt.x / 2 + 5, batt.y - 0.2, bot_h + 10]) cube([batt.x - 10, foam, batt.z - 20]);
    if (show("tp4056")) translate([tp_x0, tp_y, wall]) {
        color("MediumBlue") cube([tp.x, tp.z, tp.y]);
        color("Silver") translate([tp.x / 2 - 4.5, tp.z, -2]) cube([9, tp_usb_h, 9.3]);
        color("Black") translate([tp.x / 2 - 2.5, tp.z, 12]) cube([5, 1.5, 5]);
    }
    if (show("switch")) translate([sw_x - sw.x / 2, usb_y - sw.y / 2, wall]) {
        color("Black") cube([sw.x, sw.y, sw.z]);
        color("Silver") for (i = [0 : 2]) translate([1.5 + i * 2.5, sw.y / 2, sw.z]) cube([0.5, 0.3, 2]);
        color("WhiteSmoke") translate([sw.x / 2 - 0.75, sw.y / 2 - 0.75, -2.5]) cube([1.5, 1.5, 2.5]);
    }
    if (show("wires")) {
        top = wall + tp.y;
        bat = [xiao_pos.x - 0.5, xiao_pos.y + 9, xiao_pos.z + 4];
        wire([[-10, batt.y / 2, bot_h - 2], [tp_x1 - 4, tp_y + 3, top + 1], [tp_x1 - 4, tp_y + 1, top - 1]], "Red");
        wire([[10, batt.y / 2, bot_h - 2], [tp_x0 + 8, tp_y + 4, top + 2], [tp_x0 + 8, tp_y + 1, top - 1]], "Black");
        wire([[tp_x0 + 4, tp_y + 1, top - 1], [sw_x - 2.5, usb_y, wall + sw.z + 2]], "Red");
        wire([[sw_x + 2.5, usb_y, wall + sw.z + 2], [-0.6, D - 5, bot_h], [-0.6, D - 5, H - 2], [20, 20, H + 2], bat], "Red");
        wire([[tp_x0 + 12, tp_y + 1, top - 1], [0.6, D - 5, bot_h], [0.6, D - 5, H - 2], [20, 19, H + 3], bat + [0, 1.5, -1]], "Black");
    }
}
module hood_contents() {
    if (show("xiao")) translate(xiao_pos) {
        color("DimGray") translate([xiao[2] - 1.2, 0, 0]) cube([1.2, xiao[1], xiao[0]]);
        color("Silver") translate([2, 2, 2]) cube([xiao[2] - 3.2, xiao[1] - 4, 10]);
        color("Black") cube([1.2, xiao[1] - 3, xiao[0] - 3]);
        color("Ivory") translate([-2.5, 1.5, xiao[0] - 7.5]) cube([2.5, xiao[1] - 6, 4]);
        color("Silver") translate([xiao[2] - 4.4, xiao[1] / 2 - 4.5, -1.5]) cube([3.2, 9, 7]);
    }
    if (show("antenna")) color("Tan") translate([-22, 2, Ht - wall - 0.2]) cube([45, 12, 0.2]);
    if (show("flex")) color("Orange") {
        // from the back of the ball, down and round to the XIAO connector
        translate([-3, eye_y - ball_r - 1, ec.z - 6]) cube([6, 0.3, 4]);
        translate([-3, eye_y - ball_r - 2, ec.z - 7]) cube([6, 3, 0.3]);
        translate([-3, eye_y - ball_r - 2, ec.z - 7]) cube([xiao_pos.x - 2.5 + 3, 0.3, 0.3 + 1]);
        translate([xiao_pos.x - 2.8, xiao_pos.y + 4, ec.z - 7]) cube([0.3, 9, 3]);
    }
}
// in ball coordinates (lens towards +y)
module eye_contents() {
    if (show("camera")) translate([0, ball_r - lens_recess, 0]) {
        color("Black") rotate([90, 0, 0]) cylinder(d = 10, h = cam_len - cam_sq_d);
        color("Black") translate([-cam_sq / 2, -cam_len + 0.3, -cam_sq / 2]) cube([cam_sq, cam_sq_d - 0.3, cam_sq]);
        color("SteelBlue") translate([-cam_sq / 2, -cam_len, -cam_sq / 2]) cube([cam_sq, 0.3, cam_sq]);
    }
}

// ---------- placement ----------
module at_eye() { translate(ec) rotate(eye_pan) rotate([-eye_tilt, 0, 0]) children(); }

module on_wedge() {
    if (show_wedge) translate([wedge_pivot.x, wedge_pivot.y, 0]) rotate(-wedge) translate([-wedge_pivot.x, -wedge_pivot.y, 0]) children();
    else children();
}
module assembled(explode = 0, lid_on = true) {
    if (show_wedge) color("Tan") { wedge_top(); wedge_bottom(); }
    on_wedge() assembled_tower(explode, lid_on);
}
module assembled_tower(explode = 0, lid_on = true) {
    color("Gainsboro") tower();
    if (lid_on) color("Silver", 0.5) translate([0, -explode * 1.5, 0]) back();
    if (show_parts) translate([0, explode * 0.6, 0]) tower_contents();
    if (show_foot) color("DimGray") translate([0, 0, -3 - explode * 1.5]) foot();
    translate([0, 0, explode * 2.5]) {
        color("DimGray", lid_on ? 1 : 0.35) hood();
        color("SlateGray") translate([0, -explode * 1.2, 0]) clamp();
        if (show_parts) translate([0, -explode * 0.6, 0]) hood_contents();
        translate([0, explode * 1.5, 0]) at_eye() { color([0.15, 0.15, 0.17]) eye(); if (show_parts) eye_contents(); }
    }
}
module cut(c) difference() { color(c) children(); color(c) translate([-200, -100, -50]) cube([200, 300, 400]); }

if (part == "tower") tower();
else if (part == "hood") translate([0, 0, Ht]) rotate([180, 0, 0]) hood();
else if (part == "back") rotate([-90, 0, 0]) translate([0, pt, 0]) back();
else if (part == "eye") eye();
else if (part == "clamp") rotate([90, 0, 0]) translate([0, -eye_y + 6.3, -ec.z]) clamp();
else if (part == "foot") foot();
else if (part == "wedge_top") rotate([90, 0, 0]) translate([0, pt, 0]) wedge_top();
else if (part == "wedge_bottom") rotate([90, 0, 0]) translate([0, pt, 0]) wedge_bottom();
else if (part == "print_all") {
    tower();
    translate([W + 15, 0, 0]) rotate([-90, 0, 0]) translate([0, pt, 0]) back();
    translate([-W - 15, 0, Ht]) rotate([180, 0, 0]) hood();
    translate([-W - 15, -50, ball_r]) eye();
    translate([-W + 25, -50, 0]) rotate([90, 0, 0]) translate([0, -eye_y + 6.3, -ec.z]) clamp();
    translate([0, -110, 0]) foot();
    translate([W + 15, -110, 0]) rotate([90, 0, 0]) translate([0, pt, 0]) wedge_top();
    translate([W + 15, -170, 0]) rotate([90, 0, 0]) translate([0, pt, 0]) wedge_bottom();
}
// pieces for the web viewer: everything in place, except the eye (ball coordinates)
else if (part == "x_tower") tower();
else if (part == "x_hood") hood();
else if (part == "x_back") back();
else if (part == "x_clamp") clamp();
else if (part == "x_foot") translate([0, 0, -3]) foot();
else if (part == "x_eye") eye();
else if (part == "x_wedge_top") wedge_top();
else if (part == "x_wedge_bottom") wedge_bottom();
else if (part == "x_tower_dummy") tower_contents();
else if (part == "x_hood_dummy") hood_contents();
else if (part == "x_eye_dummy") eye_contents();
else if (part == "inside") assembled(lid_on = false);
else if (part == "exploded") assembled(explode = 14);
else if (part == "section") {
    cut("Gainsboro") tower();
    cut("Silver") back();
    cut("DimGray") hood();
    cut("SlateGray") clamp();
    if (show_foot) cut("DimGray") translate([0, 0, -3]) foot();
    at_eye() cut([0.15, 0.15, 0.17]) eye();
    if (show_parts) { tower_contents(); hood_contents(); at_eye() eye_contents(); }
}
else assembled();

echo(str("VIEWER {\"W\":", W, ",\"D\":", D, ",\"pt\":", pt, ",\"H\":", H, ",\"Ht\":", Ht,
         ",\"eye\":[", ec.x, ",", ec.y, ",", ec.z, "]}"));
