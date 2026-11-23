// Living-room camera enclosure - parametric OpenSCAD model (v9: disguised as a motion detector).
//
// A slim upright tower with a flat back, flat sides near the back and a front that
// is a circular arc, so it hangs flat on a wall, sits into a left or right corner,
// or stands on a cupboard (in the optional foot). The top part (hood) continues the
// same shape; its only feature is a thin dark slit along the arc.
//   - tower: the battery stands against the back plate; side ribs, a shelf below,
//     ledges above and two front ribs (on a foam pad) hold it. Below it the TP4056
//     stands up with its USB-C opening in the bottom face, next to the switch lever.
//     The XIAO stands against the back plate above the battery.
//   - hood: print it dark. Inside, a carriage slides along two arc rails behind the
//     slit (that is the left/right aiming: the lens always looks straight out of the
//     arc, so sliding it 38 degrees round the arc turns it 38 degrees). In the
//     carriage a rocker holds the camera; its pins run in two arc slots centred on
//     the lens tip (a "virtual pivot"), so it tilts up/down about the lens itself and
//     the lens never leaves the slit. The lens tip sits in the outer surface, so the
//     slit never cuts into the picture.
//   - slit tiles: the rest of the slit is filled with small ribbed tiles (like the
//     lens strip of a motion detector) that press in from outside and are held by a
//     lip and two friction bumps. To move the camera: pull out the tiles on one
//     side, slide the carriage over, push them back in on the other side. Tiles come
//     in six widths, so any position can be filled to within a couple of mm; print
//     the spare set too - this is meant to work from a single print.
//   - back plate: full height, closes tower and hood; two keyholes (nail, screw,
//     picture hook) and a flat face for adhesive strips.
//   - wedges (optional): angle the whole tower 20 or 30 degrees off the wall; the top
//     one carries two pegs for the keyholes, the bottom one is a spacer.
// Disguise: it is dressed as the motion detector of an alarm system - print the
// tower, hood, back plate and foot in white, the tiles and the carriage in black
// (the ribbed dark strip then reads as a detector lens). Under the strip there is
// an engraved model number and a small "LED" window (a dab of dark or red nail
// polish makes it look real).
// The XIAO's LEDs must stay off in the firmware, or they glow through the slit.
//
// Pick what to show/export with `part`, then Render (F6) and export STL.
// Print in PETG or ASA, 0.2 mm layers, 3 walls. Tower upright, hood upside down
// (the rails may want a little support), back plate flat (wall side down),
// carriage on its back, rocker on its side, tiles face up, foot flat. print_all
// lays out everything plus spares of the small moving parts. Clearances are generous
// (0.3-0.4 mm) on purpose; if something is loose, felt tape or a drop of glue fixes
// it, if tight, a few strokes of sandpaper.
//
// Hardware: 4x M3x8 (back plate), self-tapping (wedges: 2 wall screws each, or
// adhesive strips); soft silicone wire 26-28 AWG; 1.5-2 mm foam tape; felt tape if
// the carriage slides too freely.

part = "assembly";  // [assembly, inside, exploded, section, tower, hood, back, carriage, rocker, foot, wedge_top, wedge_bottom, print_all]
cam_pan = 0;        // preview: degrees the carriage is slid round to the left (-38..38)
cam_tilt = 25;      // preview: degrees the camera looks down (-5..40)
wedge = 30;         // wedge angle (20 or 30); the preview uses it when show_wedge
show_wedge = false;
show_parts = true;
show_foot = true;
tile_len = 16;      // export helper

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
flat = 16;                // flat part of each side, from the back
arc_a = 53;               // the front arc runs this many degrees either side
bot_h = 29;               // bottom compartment: battery shelf top
top_h = 16;               // above the battery (keyholes, XIAO)
hood_h = 44;

/* [Openings] */
usb_w = 9.6;  usb_h = 4.0;
plug_w = 12.5; plug_h = 7;
switch_slot = [5.5, 2.2];

/* [Slider] */
slit_up = 22;             // slit centre above the hood bottom
slit_h = 18;
slit_a = 50;              // slit runs this many degrees either side
car_w = 8.2;              // carriage half width
car_d = 18;               // carriage depth behind the lens tip
car_h = 13.7;             // carriage half height
rail_gap = 14;            // rail bands start this far above/below the slit centre
pin_r = [10, 16];         // rocker pins: distance from the lens tip
pin_d = 3;                // rocker pins (slots are 0.4 wider)
tilt_range = [-5, 40];
face_out = 0.8;           // tile faces and the carriage nose stand this far proud
tile_lens = [16, 12, 8, 6, 4, 3];   // tile widths along the arc, mm

/* [Disguise] */
label = "PIR-210";        // engraved under the strip (a made-up model number)
label_size = 3.2;
label_z = -15;            // relative to the slit centre
led_a = -24;              // fake LED window: degrees round the arc, and its size
led_d = 3;
cam_sq = 8.5;
cam_sq_d = 4.2;
cam_len = 12.4;

/* [Screws] */
pilot_d = 2.5;
screw_d = 3.4;

$fn = 48;

// ---------- derived ----------
W = batt.x + 2 * side_clear + 2 * wall;
R = (W / 2) / sin(arc_a);             // front arc radius
yc = flat - R * cos(arc_a);           // arc centre (behind the wall)
D = yc + R;                           // depth in the middle
H = bot_h + batt.z + 1 + top_h;       // tower height
Ht = H + hood_h;                      // overall height
sc = [0, yc, H + slit_up];            // arc centre at slit height
nose_a = car_w / R * 180 / PI;        // half angle of the carriage nose
tp_x0 = -24; tp_x1 = tp_x0 + tp.x;
tp_y = 8;
usb_y = tp_y + tp.z + tp_usb_h / 2;
sw_x = 15;
kh_z = H - 10;
bp_screws = [for (s = [-1, 1], z = [14, Ht - 6]) [s * (W / 2 - wall - 3.1), z]];
xiao_pos = [-xiao[1] / 2, 0.5, H - 15];   // standing against the back plate, above the battery

// ---------- profile ----------
// Seen from above: x across, y away from the wall (0 = back plate front face).
module prof(o = 0) {
    offset(r = o) offset(r = 2) offset(delta = -2) union() {
        translate([-W / 2, 0]) square([W, flat]);
        intersection() {
            translate([0, yc]) circle(R, $fn = 240);
            translate([-W / 2, 0]) square([W, D + 1]);
        }
    }
}
module outline(o = 0) { offset(r = o) union() { prof(); translate([-W / 2, -pt]) offset(r = 2) offset(delta = -2) square([W, pt + 3]); } }
module slot(w, h, depth) {
    hull() for (x = [-(w - h) / 2, (w - h) / 2]) translate([x, 0, 0]) cylinder(d = h, h = depth);
}
// annular sector round the arc centre, centred on +y, from radius r0 to r1
module arc_band(r0, r1, a, h) {
    rotate(90 - a) rotate_extrude(angle = 2 * a, $fn = 160) translate([r0, 0]) square([r1 - r0, h]);
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
                intersection() {
                    translate([s * 22 - 1.2, batt.y + foam, bot_h]) cube([2.4, D, batt.z]);
                    linear_extrude(H) prof(-wall + 0.01);
                }
                translate([s * (W / 2 - wall - 3.1), 3.1, 0]) cylinder(r = 3.4, h = 20);
            }
            for (x = [tp_x0 + 0.5, tp_x1 - 0.5]) translate([x, tp_y + tp.z / 2, wall + 6]) difference() {
                cube([4, 5, 12], center = true);
                cube([5, tp.z + 0.3, 13], center = true);   // the PCB edge slides into this slot
            }
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
            // two rail bands behind the front wall, above and below the slit, with a
            // 45-degree underside / top so they print
            intersection() {
                union() for (s = [-1, 1]) translate([0, yc, sc.z + s * (rail_gap + 1.5) - 1.5]) hull() {
                    arc_band(R - 9, R - wall + 0.01, slit_a + 20, 3);
                    translate([0, 0, s > 0 ? 3 + 4 : -4]) arc_band(R - wall - 0.5, R - wall + 0.01, slit_a + 20, 0.01);
                }
                translate([0, 0, H]) linear_extrude(hood_h) prof(-0.01);
            }
            for (s = [-1, 1]) translate([s * (W / 2 - wall - 3.1), 3.1, Ht - 10]) cylinder(r = 3.4, h = 10);
        }
        // the slit, and the grooves the carriage tongues run in
        translate([0, yc, sc.z - slit_h / 2]) arc_band(R - 6, R + 2, slit_a, slit_h);
        for (s = [-1, 1]) translate([0, yc, s > 0 ? sc.z + rail_gap - 0.01 : sc.z - rail_gap - 1.5])
            arc_band(R - 6.6, R - 4.4, slit_a + 20, 1.51);
        for (p = bp_screws) if (p[1] > H) translate([p[0], -1, p[1]]) rotate([-90, 0, 0]) cylinder(d = pilot_d, h = 9);
        for (s = [-1, 1], i = [0 : 3]) translate([s * 20 - 1 + (i - 1.5) * 4.5, 4, Ht - wall - 1]) cube([2, 10, wall + 2]);
        // engraved model number, one letter at a time round the arc so it stays even
        translate([sc.x, sc.y, sc.z + label_z]) for (i = [0 : len(label) - 1])
            rotate(((i - (len(label) - 1) / 2) * label_size * 0.75) / R * 180 / PI)
                translate([0, R - 0.6, 0]) rotate([90, 0, 180]) mirror([0, 0, 1]) translate([0, 0, -2])
                    linear_extrude(2.01) text(label[i], size = label_size, font = "Liberation Sans:style=Bold", halign = "center", valign = "center");
        // fake LED window
        translate([sc.x, sc.y, sc.z + label_z]) rotate(led_a) translate([0, R - 1, 0]) rotate([-90, 0, 0]) cylinder(d = led_d, h = 3, $fn = 24);
    }
}

// ---------- carriage and rocker ----------
// Carriage coordinates: origin at the lens tip, +y straight out of the arc.
module at_carriage(a) { translate([sc.x, sc.y, sc.z]) rotate(a) translate([0, R + face_out, 0]) children(); }
// a slot along an arc of radius r round the lens tip, in the y-z plane, through x
module tip_arc_slot(r, w, x0, x1) {
    for (a = [tilt_range[0] : 5 : tilt_range[1] - 5]) hull() for (b = [a, a + 5])
        translate([x0, -r * cos(b), r * sin(b)]) rotate([0, 90, 0]) cylinder(d = w, h = x1 - x0, $fn = 16);
}
module carriage_local() {
    difference() {
        union() {
            translate([-car_w, -car_d, -car_h]) cube([2 * car_w, car_d, 2 * car_h]);
            // tongues for the rail grooves
            for (s = [-1, 1]) translate([-car_w, -6.4 - face_out, s > 0 ? car_h - 0.01 : -car_h - 1.5]) cube([2 * car_w, 1.8, 1.51]);
        }
        // room for the rocker, open at the front (lens) and the top (to drop it in)
        translate([-6.2, -car_d + 0.5, -10.5]) cube([12.4, car_d + 1.5, 30]);
        // the camera flex leaves at the bottom
        translate([-4, -car_d - 1, -car_h - 3]) cube([8, car_d - 3, 5]);
        // two arc slots in each cheek, both centred on the lens tip, open to the top
        for (r = pin_r) {
            tip_arc_slot(r, pin_d + 0.4, -car_w - 1, car_w + 1);
            translate([-car_w - 1, -r * cos(tilt_range[1]) - (pin_d + 0.4) / 2, r * sin(tilt_range[1])]) cube([2 * car_w + 2, pin_d + 0.4, 20]);
        }
    }
}
module carriage(a = 0) {
    intersection() {
        at_carriage(a) carriage_local();
        // front follows the inside of the wall
        translate([sc.x, sc.y, sc.z - 30]) cylinder(r = R - wall - 0.3, h = 60, $fn = 240);
    }
    nose(a);
}
// The carriage's front: fills its part of the slit, flush with the tile faces, with
// the lens opening and the same ribs as the tiles.
module nose(a) {
    hn = slit_h - 0.6;
    difference() {
        translate([sc.x, sc.y, sc.z - hn / 2]) rotate(a) arc_band(R - wall - 0.5, R + face_out, nose_a - 0.2, hn);
        at_carriage(a) translate([0, -6, 0]) rotate([-90, 0, 0])
            linear_extrude(8) offset(r = 3) square([11 - 6, 15.5 - 6], center = true);
        translate([sc.x, sc.y, sc.z - hn / 2 - 1]) rotate(a) ribs(2 * car_w, hn + 2);
    }
}
// vertical grooves on a face of radius R + face_out, every 2 mm, centred on +y
module ribs(len, h) {
    n = floor(len / 2);
    for (i = [0 : n - 1]) rotate(((i - (n - 1) / 2) * 2) / (R + face_out) * 180 / PI)
        translate([-0.4, R + face_out - 0.4, 0]) cube([0.8, 1, h]);
}
// One slit tile, centred on +y (arc-centre coordinates, slit centre at z = 0).
module tile(len) {
    hs = slit_h - 0.4;
    hf = slit_h + 2.4;
    difference() {
        union() {
            translate([0, 0, -hs / 2]) arc_band(R - wall + 0.1, R + 0.01, (len / 2 - 0.15) / R * 180 / PI, hs);
            translate([0, 0, -hf / 2]) arc_band(R, R + face_out, (len / 2 - 0.05) / R * 180 / PI, hf);
            // friction bumps on the stem, top and bottom
            for (z = [-1, 1]) translate([0, R - wall / 2, z * hs / 2]) scale([min(len - 1, 3), 1.2, 0.6]) sphere(d = 1, $fn = 12);
        }
        translate([0, 0, -hf / 2 - 1]) ribs(len, hf + 2);
    }
}
function fill(L) = L < tile_lens[len(tile_lens) - 1] ? [] :
    let(w = [for (x = tile_lens) if (x <= L) x][0]) concat([w], fill(L - w));
function cumsum(v, i = 0, acc = 0) = i >= len(v) ? [] : concat([acc + v[i] / 2], cumsum(v, i + 1, acc + v[i]));
// tiles laid out round the carriage for a given pan, outwards from the nose
module tiles_for(a) {
    for (side = [-1, 1]) {
        edge = a + side * nose_a;
        L = (side > 0 ? slit_a - edge : edge + slit_a) / 180 * PI * R;
        ws = fill(L);
        cs = cumsum(ws);
        if (len(ws) > 0) for (i = [0 : len(ws) - 1]) translate([sc.x, sc.y, sc.z]) rotate(edge + side * cs[i] / R * 180 / PI) tile(ws[i]);
    }
}
// the carriage with its nose, lying on its back for printing
module carriage_print() {
    rotate([-90, 0, 0]) translate([0, car_d, 0]) translate([0, -(sc.y + R + face_out), -sc.z]) carriage(0);
}
// Rocker coordinates: origin at the lens tip, lens along +y.
module rocker() {
    difference() {
        union() {
            translate([-5.45, -cam_len - 0.6, -5.45]) cube([10.9, cam_sq_d + 0.6 + 0.3, 10.9]);   // holder tube
            translate([-5.45, -pin_r[1] - 1.2, -2]) cube([10.9, pin_r[1] + 1.2 - cam_len, 4]);   // tail
            for (r = pin_r) translate([-car_w + 0.3, -r, 0]) rotate([0, 90, 0]) cylinder(d = pin_d, h = 2 * car_w - 0.6, $fn = 16);
        }
        translate([-4.45, -cam_len, -4.45]) cube([8.9, cam_sq_d + 1, 8.9]);                       // camera pocket
        translate([-3.5, -cam_len - 1, -5.5]) cube([7, cam_sq_d, 2.5]);                            // flex exit
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
// left, so the front turns to the right. Mirror it in the slicer for the other side.
wedge_pivot = [W / 2, -pt];
module wedge_body(z0, h) {
    c = wedge_pivot + W * [-cos(wedge), sin(wedge)];
    translate([0, 0, z0]) linear_extrude(h) polygon([wedge_pivot, [-W / 2, -pt], c]);
}
function on_face(d, o = 0) = wedge_pivot + d * [-cos(wedge), sin(wedge)] + o * [sin(wedge), cos(wedge)];
module wall_holes(z) {
    for (x = [-W / 2 + 12, -W / 2 + 34]) translate([x, -pt - 1, z]) rotate([-90, 0, 0]) {
        cylinder(d = 4.2, h = 60);
        translate([0, 0, 5]) cylinder(d = 8, h = 60);
    }
}
module wedge_top() {
    difference() {
        union() {
            wedge_body(kh_z - 12, 30);
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
module wedge_bottom() { difference() { wedge_body(8, 30); wall_holes(23); } }

// ---------- dummies (preview only) ----------
only = "";
function show(n) = only == "" || only == n;
module wire(pts, c) color(c) for (i = [0 : len(pts) - 2]) hull() {
    translate(pts[i]) sphere(d = 1.2, $fn = 8);
    translate(pts[i + 1]) sphere(d = 1.2, $fn = 8);
}
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
    // XIAO standing against the back plate, battery pads towards the plate
    if (show("xiao")) translate(xiao_pos) {
        color("DimGray") cube([xiao[1], 1.2, xiao[0]]);
        color("Silver") translate([2, 1.2, 2]) cube([xiao[1] - 4, xiao[2] - 2.4, 10]);
        color("Black") translate([0, xiao[2] - 1.2, 0]) cube([xiao[1] - 3, 1.2, xiao[0] - 3]);
        color("Ivory") translate([1.5, xiao[2], xiao[0] - 7.5]) cube([xiao[1] - 6, 2.5, 4]);
    }
    if (show("wires")) {
        top = wall + tp.y;
        bat = [0, xiao_pos.y + 0.5, xiao_pos.z + 8];
        wire([[-10, batt.y / 2, bot_h - 2], [tp_x1 - 4, tp_y + 3, top + 1], [tp_x1 - 4, tp_y + 1, top - 1]], "Red");
        wire([[10, batt.y / 2, bot_h - 2], [tp_x0 + 8, tp_y + 4, top + 2], [tp_x0 + 8, tp_y + 1, top - 1]], "Black");
        wire([[tp_x0 + 4, tp_y + 1, top - 1], [sw_x - 2.5, usb_y, wall + sw.z + 2]], "Red");
        wire([[sw_x + 2.5, usb_y, wall + sw.z + 2], [-0.6, D - 6, bot_h], [-0.6, D - 6, H - 16], [-0.6, 16, H - 14], bat], "Red");
        wire([[tp_x0 + 12, tp_y + 1, top - 1], [0.6, D - 6, bot_h], [0.6, D - 6, H - 16], [0.6, 16, H - 15], bat + [1.2, 0, -1]], "Black");
    }
}
module hood_contents() {
    if (show("antenna")) color("Tan") translate([-22, 2, Ht - wall - 0.2]) cube([45, 12, 0.2]);
    if (show("flex")) color("Orange") {
        // from under the carriage down to the XIAO connector (it has slack to slide)
        hull() { translate([-3, D - 14, sc.z - car_h - 2]) cube([6, 0.3, 0.3]); translate([-3, 12, H + 4]) cube([6, 0.3, 0.3]); }
        hull() { translate([-3, 12, H + 4]) cube([6, 0.3, 0.3]); translate([-3, xiao_pos.y + xiao[2] + 2.5, xiao_pos.z + xiao[0] - 5]) cube([6, 0.3, 0.3]); }
    }
}
// in rocker coordinates
module rocker_contents() {
    if (show("camera")) {
        color("Black") rotate([90, 0, 0]) cylinder(d = 10, h = cam_len - cam_sq_d);
        color("Black") translate([-cam_sq / 2, -cam_len + 0.3, -cam_sq / 2]) cube([cam_sq, cam_sq_d - 0.3, cam_sq]);
        color("SteelBlue") translate([-cam_sq / 2, -cam_len, -cam_sq / 2]) cube([cam_sq, 0.3, cam_sq]);
    }
}

// ---------- placement ----------
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
    if (show_foot && !show_wedge) color("DimGray") translate([0, 0, -3 - explode * 1.5]) foot();
    translate([0, 0, explode * 2.5]) {
        color("DimGray", lid_on ? 1 : 0.35) hood();
        if (show_parts) hood_contents();
        translate([0, -explode * 1.2, 0]) {
            color("SlateGray") carriage(cam_pan);
            color([0.22, 0.23, 0.25]) translate([0, explode * 1.2, 0]) tiles_for(cam_pan);
            at_carriage(cam_pan) rotate([-cam_tilt, 0, 0]) translate([0, explode * 0.8, 0]) {
                color("Peru") rocker();
                if (show_parts) rocker_contents();
            }
        }
    }
}
module cut(c) difference() { color(c) children(); color(c) translate([-200, -100, -50]) cube([200, 300, 400]); }

if (part == "tower") tower();
else if (part == "hood") translate([0, 0, Ht]) rotate([180, 0, 0]) hood();
else if (part == "back") rotate([-90, 0, 0]) translate([0, pt, 0]) back();
else if (part == "carriage") carriage_print();
else if (part == "rocker") rotate([0, 90, 0]) rocker();
else if (part == "tiles") for (i = [0 : len(tile_lens) - 1], k = [0 : 3]) translate([i * 20, k * 26, R + face_out]) rotate([-90, 0, 0]) tile(tile_lens[i]);
else if (part == "foot") foot();
else if (part == "wedge_top") rotate([90, 0, 0]) translate([0, pt, 0]) wedge_top();
else if (part == "wedge_bottom") rotate([90, 0, 0]) translate([0, pt, 0]) wedge_bottom();
else if (part == "print_all") {
    tower();
    translate([W + 15, 0, 0]) rotate([-90, 0, 0]) translate([0, pt, 0]) back();
    translate([-W - 15, 0, Ht]) rotate([180, 0, 0]) hood();
    translate([-W - 15, -50, 0]) carriage_print();
    translate([-W + 15, -50, 0]) rotate([0, 90, 0]) rocker();
    // spares of the small moving parts, and four of each tile width (plenty)
    translate([-W + 35, -50, 0]) rotate([0, 90, 0]) rocker();
    translate([-W + 55, -50, 0]) rotate([0, 90, 0]) rocker();
    translate([-W - 60, -50, 0]) carriage_print();
    for (i = [0 : len(tile_lens) - 1], k = [0 : 3]) translate([-W - 140 + i * 20, -100 - k * 26, R + face_out]) rotate([-90, 0, 0]) tile(tile_lens[i]);
    translate([0, -110, 0]) foot();
}
// pieces for the web viewer: everything in place except the carriage (arc-centre
// coordinates) and the rocker (rocker coordinates)
else if (part == "x_tower") tower();
else if (part == "x_hood") hood();
else if (part == "x_back") back();
else if (part == "x_foot") translate([0, 0, -3]) foot();
else if (part == "x_carriage") translate(-sc) carriage(0);
else if (part == "x_rocker") rocker();
else if (part == "x_tile") tile(tile_len);
else if (part == "x_wedge_top") wedge_top();
else if (part == "x_wedge_bottom") wedge_bottom();
else if (part == "x_tower_dummy") tower_contents();
else if (part == "x_hood_dummy") hood_contents();
else if (part == "x_rocker_dummy") rocker_contents();
else if (part == "inside") assembled(lid_on = false);
else if (part == "exploded") assembled(explode = 14);
else if (part == "section") {
    cut("Gainsboro") tower();
    cut("Silver") back();
    cut("DimGray") hood();
    cut("SlateGray") carriage(cam_pan);
    if (show_foot) cut("DimGray") translate([0, 0, -3]) foot();
    at_carriage(cam_pan) rotate([-cam_tilt, 0, 0]) cut("Peru") rocker();
    if (show_parts) { tower_contents(); hood_contents(); at_carriage(cam_pan) rotate([-cam_tilt, 0, 0]) rocker_contents(); }
}
else assembled();

echo(str("VIEWER {\"W\":", W, ",\"D\":", D, ",\"pt\":", pt, ",\"H\":", H, ",\"Ht\":", Ht,
         ",\"R\":", R, ",\"sc\":[", sc.x, ",", sc.y, ",", sc.z, "]}"));
