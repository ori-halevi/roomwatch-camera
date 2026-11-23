// Living-room camera enclosure - parametric OpenSCAD model (v3).
//
// Two bodies, so the heavy part never moves when aiming:
//   - base (fixed, flat on the shelf): battery bay with side ribs and end stops, a
//     foam pad on the battery squeezed by the lid, and a front compartment with the
//     TP4056 (USB-C out the right side) and the switch (left side).
//   - head (small, aimed by hand): XIAO + camera + antenna. It sits on a ball joint:
//     loosen the two ring screws, point it (about 35 degrees any way, and all the way
//     round), tighten. Only two thin wires (battery + / -) run up through the hollow
//     mast and ball, so the camera flex never bends when aiming.
// The 75 mm camera module sits in a pocket behind the lens hole; a retainer plate,
// the XIAO and a foam pad stack up behind it and the back cover holds it all.
//
// Pick what to show/export with `part`, then Render (F6) and export STL.
// Print in PETG or ASA, 0.2 mm layers, 3 walls. Base upright (open side up), lid
// flat (outside down), mast upright with support under the ball only, head on its
// back face, ring and cover and retainer flat.
//
// Hardware: 4x M3x10 (lid), 2x M3x10 (ball ring), 2x M3x8 (head back cover), all
// self-tapping into plastic; soft silicone wire 26-28 AWG; 1.5-2 mm foam tape.

part = "assembly";  // [assembly, inside, exploded, section, base, lid, mast, head, ring, cover, retainer, print_all]
tilt = 15;          // assembly preview: degrees the head looks down (-35..35)
pan = 0;            // assembly preview: degrees the head is turned to the left
show_parts = true;  // draw the electronics dummies in the previews

/* [Base contents - measured] */
batt = [110, 61, 14];     // battery: length incl. the sealed edge, width, max thickness
foam = 1.5;               // foam pad on the battery, pressed by the lid
side_clear = 1.5;         // each side of the battery (the ribs take 1 mm of it)
gap_front = 32;           // front compartment: TP4056, switch, mast, battery tabs
gap_rear = 7.5;           // behind the battery: lid posts
tp = [18.5, 25, 1.6];     // TP4056: x (across), y (along, USB end at the wall), PCB
tp_usb_h = 3.2;           // receptacle height above the PCB
sw = [9, 3.5, 3];         // slide switch: length, body height (towards the wall), thickness

/* [Shell] */
wall = 2.2;
lid_t = 2.2;
fit = 0.3;
corner_r = 3;

/* [Side openings] */
usb_w = 9.6;  usb_h = 4.0;
plug_w = 12.5; plug_h = 7;
switch_slot = [5.5, 2.2];

/* [Ball joint] */
ball_r = 8;
neck_r = 3;               // mast neck (the wires go through it)
bore_d = 3.2;             // wire channel through mast and ball
ball_up = 16;             // ball centre above the lid
mast_x = 15;              // mast position in the base (from the front face)
mast_foot = 12;           // square foot, sits in a socket on the base floor
flange_d = 24;            // under the lid; the plug above it fills the lid hole
plug_d = 16.3;
split = 0.3;              // half-gap between head and ring: what the screws squeeze
ring_t = 6;
ring_hold = 4.5;          // ring grips the ball down to this depth below its centre

/* [Head] */
cam_sq = 8.5;             // camera module (OV2640-75MM drawing)
cam_sq_d = 4.2;
cam_len = 12.4;
lens_bore = 10.4;         // lens measured 10 mm
lens_recess = 0.5;
xiao = [21, 17.8, 8];     // XIAO + Sense standing up: height, width, stack thickness
head_x = [-16, 14];       // body front / back (the cover adds 2 mm behind)
head_in_w = 21;           // inside width
floor_z = 11;             // inside floor, above the ball centre
in_top = 40;              // inside top
cover_t = 2;

/* [Screws] */
post_r = 3.5;
pilot_d = 2.5;
screw_d = 3.4;

$fn = 48;

// ---------- derived ----------
in_L = gap_front + batt.x + gap_rear;
in_W = batt.y + 2 * side_clear;
Hb = wall + batt.z + foam;            // base height without lid (lid presses the foam)
Lo = in_L + 2 * wall;
Wo = in_W + 2 * wall;
batt_x = wall + gap_front;
post_in = post_r - 0.4;
posts = [for (x = [wall + post_in, Lo - wall - post_in], y = [wall + post_in, Wo - wall - post_in]) [x, y]];
mast_y = Wo / 2 - 2.2;
ball_z = Hb + lid_t + ball_up;        // ball centre, from the base bottom
tp_x0 = wall + 2 * post_r + 0.8;
tp_x1 = tp_x0 + tp.x;
usb_z = wall + tp.z + tp_usb_h / 2;
sw_x = 18;
sw_z = wall + 1 + sw.z / 2;
hw = head_in_w / 2 + wall;            // head half width outside
cam_z = floor_z + 1.5 + xiao[0] / 2;  // lens centre = XIAO centre
cam_front = head_x[0] + lens_recess + cam_len - cam_sq_d;   // front of the holder
cam_back = head_x[0] + lens_recess + cam_len;               // back of the sensor board
ret_x = [cam_back, cam_back + 1.6];   // retainer plate
xiao_x = ret_x[1] + 3;                // front face of the XIAO stack (flex + connector room)

// ---------- helpers ----------
module rounded_block(l, w, h, r) {
    hull() for (x = [r, l - r], y = [r, w - r]) translate([x, y, 0]) cylinder(r = r, h = h);
}
module slot(w, h, depth) {
    hull() for (x = [-(w - h) / 2, (w - h) / 2]) translate([x, 0, 0]) cylinder(d = h, h = depth);
}

// ---------- base ----------
module base() {
    difference() {
        union() {
            difference() {
                rounded_block(Lo, Wo, Hb, corner_r);
                translate([wall, wall, wall]) rounded_block(in_L, in_W, Hb, max(0.5, corner_r - wall));
            }
            for (p = posts) translate([p.x, p.y, 0]) cylinder(r = post_r, h = Hb);
            // battery: ribs along both sides, stops at both ends (tab end clear in the middle)
            for (x = [batt_x + 15, batt_x + batt.x / 2, batt_x + batt.x - 15], y = [wall, Wo - wall])
                translate([x, y, wall]) rotate([0, 0, y > Wo / 2 ? 180 : 0])
                    linear_extrude(batt.z - 1) polygon([[-2, -0.01], [2, -0.01], [0.6, 1], [-0.6, 1]]);
            for (y = [wall, Wo - wall - 8]) translate([batt_x - 1.6, y, wall - 0.01]) cube([1.6, 8, 8]);
            translate([batt_x + batt.x + 0.5, wall + 2 * post_r + 1, wall - 0.01]) cube([1.6, in_W - 4 * post_r - 2, 8]);
            // TP4056 pocket: rails on the long edges, stops at the inner end
            for (x = [tp_x0 - 1.4 - fit, tp_x1 + fit]) translate([x, Wo - wall - fit - tp.y - 1.5, wall - 0.01])
                cube([1.4, tp.y + 1.5 + fit, tp.z + 1.4]);
            for (x = [tp_x0 - 1.4 - fit, tp_x1 - 3 + fit]) translate([x, Wo - wall - fit - tp.y - 1.5 - fit, wall - 0.01])
                cube([4.4, 1.5, tp.z + 1.4]);
            // switch cradle against the left wall
            translate([sw_x - sw.x / 2 - 1.4 - fit, wall - 0.01, wall - 0.01]) difference() {
                cube([sw.x + 2.8 + 2 * fit, sw.y + 1.4 + 2 * fit, 1 + sw.z]);
                translate([1.4, -1, 1]) cube([sw.x + 2 * fit, sw.y + 1 + 2 * fit, sw.z + 1]);
                translate([1.4 + 1.5, sw.y, 1]) cube([sw.x + 2 * fit - 3, 3, sw.z + 1]);  // pins
            }
            // socket for the mast foot
            translate([mast_x, mast_y, wall - 0.01]) difference() {
                translate([-mast_foot / 2 - fit - 1.6, -mast_foot / 2 - fit - 1.6, 0]) cube([mast_foot + 2 * fit + 3.2, mast_foot + 2 * fit + 3.2, 2]);
                translate([-mast_foot / 2 - fit, -mast_foot / 2 - fit, -1]) cube([mast_foot + 2 * fit, mast_foot + 2 * fit, 4]);
                for (a = [0, 90, 180, 270]) rotate(a) translate([0, -2.5, -1]) cube([20, 5, 4]);   // wire gaps
            }
        }
        // USB-C on the right side, with a recess for the plug outside
        translate([(tp_x0 + tp_x1) / 2, Wo - wall - 1, usb_z]) rotate([-90, 0, 0]) slot(usb_w, usb_h, wall + 2);
        translate([(tp_x0 + tp_x1) / 2, Wo - 1, usb_z]) rotate([-90, 0, 0]) slot(plug_w, plug_h, 2);
        // switch lever window on the left side
        translate([sw_x - switch_slot.x / 2, -1, sw_z - switch_slot.y / 2]) cube([switch_slot.x, wall + 2, switch_slot.y]);
        for (p = posts) translate([p.x, p.y, Hb - 12]) cylinder(d = pilot_d, h = 13);
    }
}

// ---------- lid (in place: plate from z=0 up, pressers below; printed flipped) ----------
module lid() {
    difference() {
        union() {
            rounded_block(Lo, Wo, lid_t, corner_r);
            // pressers on the USB receptacle and on the switch
            translate([(tp_x0 + tp_x1) / 2 - 4, Wo - wall - fit - 7, -(Hb - usb_z - tp_usb_h / 2 - 0.2) + 0.01])
                cube([8, 6, Hb - usb_z - tp_usb_h / 2 - 0.2]);
            translate([sw_x - 3, wall + 0.5, -(Hb - wall - 1 - sw.z - 0.2) + 0.01]) cube([6, sw.y - 0.5, Hb - wall - 1 - sw.z - 0.2]);
        }
        for (p = posts) translate([p.x, p.y, -1]) {
            cylinder(d = screw_d, h = lid_t + 2);
            translate([0, 0, 1 + lid_t - 1.7]) cylinder(d1 = screw_d, d2 = 6.4, h = 1.71);
        }
        translate([mast_x, mast_y, -1]) cylinder(d = plug_d + 0.4, h = lid_t + 2);
        // vents over the charger (it warms up while charging)
        for (i = [0 : 3]) translate([tp_x0 + 1.5 + i * 4.5, Wo - wall - 22, -1]) cube([2, 12, lid_t + 2]);
    }
}

// ---------- mast with the ball ----------
module mast() {
    translate([mast_x, mast_y, 0]) difference() {
        union() {
            translate([-mast_foot / 2, -mast_foot / 2, wall]) cube([mast_foot, mast_foot, Hb - wall - 2 - 3]);
            // 45-degree flare up to the flange, so it prints without support
            hull() {
                translate([-mast_foot / 2, -mast_foot / 2, Hb - 5]) cube([mast_foot, mast_foot, 0.01]);
                translate([0, 0, Hb - 2]) cylinder(d = flange_d, h = 0.01);
            }
            translate([0, 0, Hb - 2]) cylinder(d = flange_d, h = 2);
            translate([0, 0, Hb]) cylinder(d = plug_d, h = lid_t);
            translate([0, 0, Hb + lid_t - 0.01]) cylinder(r = neck_r, h = ball_up);
            translate([0, 0, ball_z]) sphere(r = ball_r, $fn = 64);
        }
        translate([0, 0, wall + 1]) cylinder(d = bore_d, h = ball_z + ball_r);
        // wires leave the foot sideways, both ways
        translate([-mast_foot, -2, wall - 1]) cube([2 * mast_foot, 4, 5]);
    }
}

// ---------- head (local: origin at the ball centre, lens towards -x) ----------
module head() {
    difference() {
        union() {
            difference() {
                translate([head_x[0], -hw, split]) rounded_block(head_x[1] - head_x[0], 2 * hw, in_top + wall - split, 2);
                // inside, open at the back
                translate([cam_front, -head_in_w / 2, floor_z]) cube([head_x[1] - cam_front + 1, head_in_w, in_top - floor_z]);
            }
            // frame around the camera holder
            translate([cam_front - 0.01, -(cam_sq + 0.4) / 2 - 1.6, cam_z - (cam_sq + 0.4) / 2 - 1.6])
                cube([cam_back - cam_front, cam_sq + 3.6, cam_sq + 3.6]);
            // boss for the upper cover screw
            translate([head_x[1] - 6, 0, in_top - 3]) rotate([0, 90, 0]) cylinder(r = 3, h = 6.01);
            translate([head_x[1] - 6, -3, in_top - 3]) cube([6.01, 6, 3]);
        }
        // lens hole with a chamfer, and the pocket for the square holder
        translate([head_x[0] - 1, 0, cam_z]) rotate([0, 90, 0]) cylinder(d = lens_bore, h = cam_front - head_x[0] + 1.01);
        translate([head_x[0] - 0.01, 0, cam_z]) rotate([0, 90, 0]) cylinder(d1 = lens_bore + 2.4, d2 = lens_bore, h = 1.2);
        translate([cam_front - 0.02, -(cam_sq + 0.4) / 2, cam_z - (cam_sq + 0.4) / 2]) cube([cam_back - cam_front + 1, cam_sq + 0.4, cam_sq + 0.4]);
        // ball cup, and room for the wires to come out of the ball at any angle
        sphere(r = ball_r + 0.15, $fn = 64);
        translate([0, 0, 4]) cylinder(r = 6.4, h = floor_z);
        // wire groove along the floor to the back (the battery pads face the back)
        translate([0, -1.6, floor_z - 1.5]) cube([head_x[1] + 1, 3.2, 2]);
        // ring screw pilots (diagonal, clear of the cup) and the cover screws
        for (s = [-1, 1]) translate([8 * s, 8 * s, split - 1]) cylinder(d = pilot_d, h = 9);
        for (z = [6, in_top - 3]) translate([head_x[1] - 8, 0, z]) rotate([0, 90, 0]) cylinder(d = pilot_d, h = 9);
    }
}

// Clamp ring under the ball: two screws pull it up against the head.
module ring() {
    difference() {
        translate([-13, -hw, -split - ring_t]) rounded_block(26, 2 * hw, ring_t, 4);
        sphere(r = ball_r + 0.15, $fn = 64);
        rh = sqrt(pow(ball_r + 0.15, 2) - pow(ring_hold, 2));
        translate([0, 0, -ring_hold - 0.01]) mirror([0, 0, 1]) cylinder(r1 = rh, r2 = rh + 3, h = 3);
        for (s = [-1, 1]) translate([8 * s, 8 * s, -split - ring_t - 1]) {
            cylinder(d = screw_d, h = ring_t + 2);
            cylinder(d = 6, h = 3.5);
        }
    }
}

module cover() {
    difference() {
        translate([head_x[1], -hw, split]) cube([cover_t, 2 * hw, in_top + wall - split]);
        for (z = [6, in_top - 3]) translate([head_x[1] - 1, 0, z]) rotate([0, 90, 0]) {
            cylinder(d = screw_d, h = cover_t + 2);
            translate([0, 0, 1 + cover_t - 1.6]) cylinder(d1 = screw_d, d2 = 6.4, h = 1.61);
        }
    }
}

// Plate behind the camera; the XIAO pushes it forward. The flex leaves the camera
// at the bottom, goes down through the slot and back up to the XIAO connector.
module retainer() {
    difference() {
        translate([ret_x[0], -head_in_w / 2 + 0.2, floor_z + 0.2]) cube([ret_x[1] - ret_x[0], head_in_w - 0.4, in_top - floor_z - 0.4]);
        translate([ret_x[0] - 1, -4, floor_z - 1]) cube([3.6, 8, cam_z - cam_sq / 2 - floor_z + 1.5]);
    }
}

// ---------- dummies (preview only) ----------
only = "";
function show(n) = only == "" || only == n;
module wire(pts, c) color(c) for (i = [0 : len(pts) - 2]) hull() {
    translate(pts[i]) sphere(d = 1.2, $fn = 8);
    translate(pts[i + 1]) sphere(d = 1.2, $fn = 8);
}
// in the base (world coordinates)
module base_contents() {
    if (show("battery")) {
        color("RoyalBlue") translate([batt_x + 0.5, wall + side_clear, wall]) cube([batt.x - 1, batt.y, batt.z - 0.5]);
        color("Silver") for (dy = [18, 38]) translate([batt_x - 2, wall + side_clear + dy, wall + batt.z / 2]) cube([3, 5, 0.3]);
    }
    if (show("foam")) color("LightYellow") translate([batt_x + 10, wall + side_clear + 5, wall + batt.z - 0.5]) cube([batt.x - 20, batt.y - 10, foam]);
    if (show("tp4056")) translate([tp_x0, Wo - wall - tp.y, wall]) {
        color("MediumBlue") cube([tp.x, tp.y, tp.z]);
        color("Silver") translate([tp.x / 2 - 4.5, tp.y - 7.3, tp.z]) cube([9, 9.3, tp_usb_h]);
        color("Black") translate([tp.x / 2 - 2.5, 7, tp.z]) cube([5, 5, 1.5]);
    }
    if (show("switch")) translate([sw_x - sw.x / 2, wall, wall + 1]) {
        color("Black") cube([sw.x, sw.y, sw.z]);
        color("Silver") for (i = [0 : 2]) translate([1.5 + i * 2.5, sw.y, sw.z / 2]) cube([0.5, 1.5, 0.3]);
        color("WhiteSmoke") translate([sw.x / 2 - 0.75, -3, sw.z / 2 - 0.75]) cube([1.5, 3, 1.5]);
    }
    if (show("wires_base")) {
        tz = wall + batt.z / 2;
        wire([[batt_x - 1, wall + side_clear + 20, tz], [tp_x1 + 1.5, Wo - wall - tp.y + 2, wall + 3], [tp_x1 - 3, Wo - wall - tp.y + 2, wall + 2]], "Red");
        wire([[batt_x - 1, wall + side_clear + 40, tz], [tp_x1 + 1, Wo - wall - tp.y + 6, wall + 3], [tp_x1 - 6, Wo - wall - tp.y + 2, wall + 2]], "Black");
        wire([[tp_x0 + 3, Wo - wall - tp.y + 2, wall + 2], [mast_x, mast_y + mast_foot / 2 + 2, wall + 2], [mast_x, mast_y - mast_foot / 2 - 2, wall + 2], [sw_x + 2.5, wall + sw.y + 1.5, sw_z]], "Red");
        wire([[sw_x, wall + sw.y + 1.5, sw_z], [mast_x - 0.6, mast_y, wall + 2], [mast_x - 0.6, mast_y, ball_z]], "Red");
        wire([[tp_x0 + 6, Wo - wall - tp.y + 2, wall + 2], [mast_x + 0.6, mast_y + 3, wall + 2], [mast_x + 0.6, mast_y, wall + 2.5], [mast_x + 0.6, mast_y, ball_z]], "Black");
    }
}
// in the head (head coordinates)
module head_contents() {
    xb = xiao_x;
    if (show("xiao")) translate([xb, -xiao[1] / 2, floor_z + 1.5]) {
        color("Black") cube([1.2, xiao[1] - 3, xiao[0] - 3]);                       // Sense board
        color("Ivory") translate([-2.5, 1.5, xiao[0] - 7.5]) cube([2.5, xiao[1] - 6, 4]);  // FPC connector
        color("DimGray") translate([xiao[2] - 1.2, 0, 0]) cube([1.2, xiao[1], xiao[0]]);   // XIAO board
        color("Silver") translate([3, 2, 2]) cube([xiao[2] - 4.2, xiao[1] - 4, 10]);        // shield / stack
        color("Silver") translate([xiao[2] - 4.4, xiao[1] / 2 - 4.5, -1.5]) cube([3.2, 9, 7]);   // USB-C
    }
    if (show("camera")) translate([head_x[0] + lens_recess, 0, cam_z]) {
        color("Black") rotate([0, 90, 0]) cylinder(d = 10, h = cam_len - cam_sq_d);
        color("Black") translate([cam_len - cam_sq_d, -cam_sq / 2, -cam_sq / 2]) cube([cam_sq_d - 0.3, cam_sq, cam_sq]);
        color("SteelBlue") translate([cam_len - 0.3, -cam_sq / 2, -cam_sq / 2]) cube([0.3, cam_sq, cam_sq]);
    }
    if (show("flex")) color("Orange") {
        z0 = floor_z + 0.4;
        translate([cam_back - 0.3, -3, z0]) cube([0.3, 6, cam_z - cam_sq / 2 - z0]);
        translate([cam_back - 0.3, -3, z0]) cube([xiao_x - cam_back - 0.5, 6, 0.3]);
        translate([xiao_x - 1.1, -3, z0]) cube([0.3, 6, xiao[0] - 5]);
    }
    if (show("antenna")) color("Tan") {
        translate([cam_front + 1, -head_in_w / 2 + 2, in_top - 0.2]) cube([head_x[1] - cam_front - 2, 12, 0.2]);
        translate([cam_front + 1, -head_in_w / 2, in_top - 0.2 - 22]) cube([head_x[1] - cam_front - 2, 0.2, 22]);
    }
    if (show("wires_head")) {
        wire([[-0.6, 0, ball_r], [-0.6, 0, floor_z - 0.8], [xiao_x + xiao[2] + 1, 0, floor_z - 0.8], [xiao_x + xiao[2] + 1, -1, floor_z + 9]], "Red");
        wire([[0.6, 0, ball_r], [0.6, 0, floor_z - 0.5], [xiao_x + xiao[2] + 1.5, 1, floor_z - 0.5], [xiao_x + xiao[2] + 1.5, 1.5, floor_z + 7]], "Black");
    }
}

// ---------- output ----------
module lid_print() { translate([0, Wo, lid_t]) rotate([180, 0, 0]) lid(); }
module at_ball() { translate([mast_x, mast_y, ball_z]) rotate(pan) rotate([0, -tilt, 0]) children(); }
module head_all(explode = 0, lid_on = true) {
    color("Gainsboro") head();
    color("DimGray") translate([0, 0, -explode]) ring();
    if (lid_on) color("Silver", 0.5) translate([explode * 2, 0, 0]) cover();
    color("Peru") translate([explode * 0.6, 0, 0]) retainer();
    if (show_parts) translate([explode * 1.2, 0, 0]) head_contents();
}
module assembled(explode = 0, lid_on = true) {
    color("Gainsboro") base();
    if (show_parts) translate([0, 0, explode]) base_contents();
    if (lid_on) color("Silver", 0.45) translate([0, 0, Hb + explode * 3]) lid();
    color("SlateGray") translate([0, 0, explode * 4.5]) mast();
    translate([0, 0, explode * 6]) at_ball() head_all(explode, lid_on);
}

// Section helper: each part is cut on its own so the cut faces keep its colour.
module cut(c) difference() { color(c) children(); color(c) translate([-50, -50, -10]) cube([Lo + 100, mast_y + 50, 200]); }

if (part == "base") base();
else if (part == "lid") lid_print();
else if (part == "mast") translate([-mast_x, -mast_y, -wall]) mast();
else if (part == "head") rotate([0, -90, 0]) translate([-head_x[1], 0, 0]) head();
else if (part == "ring") translate([0, 0, split + ring_t]) ring();
else if (part == "cover") rotate([0, -90, 0]) translate([-head_x[1], 0, 0]) cover();
else if (part == "retainer") rotate([0, 90, 0]) translate([-ret_x[0], 0, 0]) retainer();
else if (part == "print_all") {
    base();
    translate([0, Wo + 10, 0]) lid_print();
    translate([Lo + 25, 20, 0]) translate([-mast_x, -mast_y, -wall]) mast();
    translate([Lo + 25, 70, 0]) rotate([0, -90, 0]) translate([-head_x[1], 0, 0]) head();
    translate([Lo + 25, 120, split + ring_t]) ring();
    translate([Lo + 65, 120, 0]) rotate([0, -90, 0]) translate([-head_x[1], 0, 0]) cover();
    translate([Lo + 90, 120, 0]) rotate([0, 90, 0]) translate([-ret_x[0], 0, 0]) retainer();
}
// pieces for the web viewer: base ones in world position, head ones in head coordinates
else if (part == "x_base") base();
else if (part == "x_lid") translate([0, 0, Hb]) lid();
else if (part == "x_mast") mast();
else if (part == "x_head") head();
else if (part == "x_ring") ring();
else if (part == "x_cover") cover();
else if (part == "x_retainer") retainer();
else if (part == "x_base_dummy") base_contents();
else if (part == "x_head_dummy") head_contents();
else if (part == "inside") assembled(lid_on = false);
else if (part == "exploded") assembled(explode = 14);
else if (part == "section") {
    cut("Gainsboro") base();
    cut("Silver") translate([0, 0, Hb]) lid();
    cut("SlateGray") mast();
    cut("Gainsboro") at_ball() head();
    cut("DimGray") at_ball() ring();
    cut("Silver") at_ball() cover();
    cut("Peru") at_ball() retainer();
    if (show_parts) { base_contents(); at_ball() head_contents(); }
}
else assembled();

echo(str("VIEWER {\"ball\":[", mast_x, ",", mast_y, ",", ball_z, "],\"Lo\":", Lo, ",\"Wo\":", Wo,
         ",\"Hb\":", Hb, ",\"lid_t\":", lid_t, "}"));
