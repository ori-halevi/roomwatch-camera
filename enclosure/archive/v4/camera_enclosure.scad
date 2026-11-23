// Living-room camera enclosure - parametric OpenSCAD model (v4: wall/corner tower).
//
// A slim upright tower with a flat back, flat sides near the back and a rounded
// front, so it hangs flat on a wall, sits into a left or right corner, or stands on
// a cupboard (in the optional foot).
//   - tower: the battery stands against the back plate; side ribs, a shelf below,
//     ledges above and two front ribs (on a foam pad) hold it. Below it the TP4056
//     stands up with its USB-C opening in the bottom face, next to the switch lever.
//   - back plate: two keyholes (nail, screw, picture hook) and a flat face for
//     adhesive strips; clamped by the crown at the top, two screws at the bottom.
//   - crown: closes the top; its neck carries the turret.
//   - turret: a yoke on a clamp collar round the neck - turns all the way round
//     (pan); the clamp screw sets how stiff it turns.
//   - head: XIAO + camera + antenna, tilting in the yoke on one M3 bolt with a
//     locking nut (about 10 degrees up to 70 down), stiffness set by the nut.
// Only two thin wires run from the battery up the front channel, through the neck
// and into the head.
//
// Pick what to show/export with `part`, then Render (F6) and export STL.
// Print in PETG or ASA, 0.2 mm layers, 3 walls. Tower upright, back plate flat
// (wall side down), crown upside down, yoke on its plate, head on its back face,
// cover/retainer/foot flat. No supports needed.
//
// Hardware: 2x M3x10 (crown) + 2x M3x8 (back plate bottom) + 2x M3x8 (head cover),
// self-tapping; 1x M3x40 + nyloc nut + 2 washers (tilt); 1x M3x16 + nut (pan clamp);
// soft silicone wire 26-28 AWG; 1.5-2 mm foam tape.

part = "assembly";  // [assembly, inside, exploded, section, tower, back, crown, yoke, head, cover, retainer, foot, print_all]
tilt = 25;          // assembly preview: degrees the head looks down (-10..70)
pan = 0;            // assembly preview: degrees the turret is turned to the left
show_parts = true;
show_foot = true;

/* [Contents - measured] */
batt = [61, 14, 110];     // battery: width, thickness, height (incl. the sealed edge)
foam = 1.5;
side_clear = 1.5;
tp = [18.5, 25, 1.6];     // TP4056: width, length (USB end down), PCB
tp_usb_h = 3.2;
sw = [9, 3.5, 3];         // switch: length, body width, body height (lever points down)

/* [Shell] */
wall = 2.2;
pt = 3;                   // back plate thickness (its back face is the wall side)
fit = 0.3;
flat = 18.5;              // flat part of each side, from the back
bulge = 9;                // the rounded front sticks out this far beyond the flats
bot_h = 29;               // bottom compartment: battery shelf top
top_h = 16;               // top compartment above the battery (keyholes, crown screws)

/* [Openings] */
usb_w = 9.6;  usb_h = 4.0;
plug_w = 12.5; plug_h = 7;
switch_slot = [5.5, 2.2];

/* [Turret] */
pan_y = 22;               // pan axis from the back plate's front face (25 from the wall)
neck_r = 7;
neck_h = 10;
collar_r = 11;
arm_t = 4;
axis_up = 17.5;           // tilt axis above the yoke plate: room for the head to swing

/* [Head] */
cam_sq = 8.5;
cam_sq_d = 4.2;
cam_len = 12.4;
lens_bore = 10.4;         // lens measured 10 mm
lens_recess = 0.5;
xiao = [21, 17.8, 8];     // XIAO + Sense standing: height, width, stack thickness
head_x = [-16, 14];       // body front / back (cover adds 2 mm)
head_in_w = 21;
floor_z = 11;
in_top = 40;
cover_t = 2;
axis_hx = -1;             // tilt axis in head coordinates
axis_hz = 5.5;

/* [Screws] */
pilot_d = 2.5;
screw_d = 3.4;
nut_af = 5.7;

$fn = 48;

// ---------- derived ----------
W = batt.x + 2 * side_clear + 2 * wall;
D = flat + bulge;
H = bot_h + batt.z + 1 + top_h;       // tower height without the crown
crown_t = 3;
Ht = H + crown_t;                     // top of the crown
hw = head_in_w / 2 + wall;
cam_z = floor_z + 1.5 + xiao[0] / 2;
cam_front = head_x[0] + lens_recess + cam_len - cam_sq_d;
cam_back = head_x[0] + lens_recess + cam_len;
ret_x = [cam_back, cam_back + 1.6];
xiao_x = ret_x[1] + 3;
plate_z = neck_h;                     // yoke plate bottom (rests on the neck top)
axis_z = plate_z + 3 + axis_up;       // tilt axis in turret coordinates
tp_x0 = -24; tp_x1 = tp_x0 + tp.x;
tp_y = 8;                             // PCB back face
usb_y = tp_y + tp.z + tp_usb_h / 2;
sw_x = 15;
kh_z = H - 10;                        // keyholes
boss_xy = [W / 2 - wall - 3.3, 17.5]; // crown screw bosses (mirrored in x)

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

// ---------- tower ----------
module tower() {
    difference() {
        union() {
            difference() {
                linear_extrude(H) prof();
                translate([0, 0, wall]) linear_extrude(H) prof(-wall);
                translate([-W / 2 + wall, -1, wall]) cube([W - 2 * wall, wall + 1.01, H]);   // open back
            }
            // battery: shelf ledges below, ledges above, side ribs, front ribs (on foam)
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
                // front rib: from the inside of the front down to the foam on the battery
                intersection() {
                    translate([s * 22 - 1.2, batt.y + foam, bot_h]) cube([2.4, D, batt.z]);
                    linear_extrude(H) prof(-wall + 0.01);
                }
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
            // bosses: back plate screws (bottom corners), crown screws (top, with a cone under)
            for (s = [-1, 1]) {
                translate([s * (W / 2 - wall - 3.1), 3.1, 0]) cylinder(r = 3.4, h = 20);
                translate([s * boss_xy.x, boss_xy.y, H - 13]) {
                    cylinder(r = 3.4, h = 13);
                    translate([0, 0, -4]) cylinder(r1 = 0.5, r2 = 3.4, h = 4.01);
                }
            }
        }
        // USB-C and switch lever through the bottom
        translate([(tp_x0 + tp_x1) / 2, usb_y, -1]) slot(usb_w, usb_h, wall + 2);
        translate([(tp_x0 + tp_x1) / 2, usb_y, -0.01]) slot(plug_w, plug_h, 1.01);
        translate([sw_x - switch_slot.x / 2, usb_y - switch_slot.y / 2, -1]) cube([switch_slot.x, switch_slot.y, wall + 2]);
        // screw pilots
        for (s = [-1, 1]) {
            translate([s * (W / 2 - wall - 3.1), -1, 14]) rotate([-90, 0, 0]) cylinder(d = pilot_d, h = 9);
            translate([s * boss_xy.x, boss_xy.y, H - 12]) cylinder(d = pilot_d, h = 13);
        }
    }
}
module slot(w, h, depth) {
    hull() for (x = [-(w - h) / 2, (w - h) / 2]) translate([x, 0, 0]) cylinder(d = h, h = depth);
}

// ---------- back plate (y from -pt to 0) ----------
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
                linear_extrude(pt) offset(r = 2) offset(delta = -2) square([W, H]);
            // pockets behind the keyholes for the screw/nail head
            for (s = [-1, 1]) translate([s * 18 - 7, -0.01, kh_z - 6]) cube([14, 4, 15]);
        }
        for (s = [-1, 1]) translate([s * 18, 0, kh_z]) {
            keyhole_cut();
            // head cavity: round entry, then a channel up
            translate([0, 4.5, 0]) rotate([90, 0, 0]) cylinder(d = 9, h = 4.5);
            translate([-4.5, 0, 0]) cube([9, 3.2, 9]);
        }
        // bottom screws, countersunk on the wall side
        for (s = [-1, 1]) translate([s * (W / 2 - wall - 3.1), 1, 14]) rotate([90, 0, 0]) {
            cylinder(d = screw_d, h = pt + 2);
            translate([0, 0, 1 + pt - 1.7]) cylinder(d1 = screw_d, d2 = 6.4, h = 1.71);
        }
    }
}

// ---------- crown (in place, z from H) ----------
module crown() {
    difference() {
        union() {
            translate([0, 0, H]) linear_extrude(crown_t) union() {
                outline();
                translate([0, pan_y]) circle(r = collar_r);   // chin under the turret
            }
            // plug into the tower opening (not over the back opening)
            translate([0, 0, H - 3]) linear_extrude(3.01) intersection() {
                prof(-wall - fit);
                translate([-W, 4.3]) square([2 * W, D]);
            }
            translate([0, pan_y, Ht - 0.01]) cylinder(r = neck_r, h = neck_h);
        }
        translate([0, pan_y, H - 5]) cylinder(d = 5, h = neck_h + 20);   // wires
        for (s = [-1, 1]) translate([s * boss_xy.x, boss_xy.y, H - 4]) {
            cylinder(d = screw_d, h = 10);
            translate([0, 0, 4 + crown_t - 1.7]) cylinder(d1 = screw_d, d2 = 6.4, h = 1.71);
        }
    }
}

// ---------- turret yoke (turret coordinates: origin on the pan axis at the crown top,
// the head looks towards -x) ----------
module yoke() {
    difference() {
        union() {
            // clamp collar round the neck, lugs at the front
            translate([0, 0, 0.2]) cylinder(r = collar_r, h = plate_z - 0.2);
            translate([-collar_r - 5, -5, 0.2]) cube([8, 10, plate_z - 0.2]);
            // plate and arms
            translate([-9, -(hw + 0.6 + arm_t), plate_z]) cube([18, 2 * (hw + 0.6 + arm_t), 3]);
            for (s = [-1, 1]) hull() {
                translate([-8, s > 0 ? hw + 0.6 : -(hw + 0.6 + arm_t), plate_z]) cube([16, arm_t, 3]);
                translate([0, s > 0 ? hw + 0.6 : -(hw + 0.6), axis_z]) rotate([s > 0 ? -90 : 90, 0, 0]) cylinder(r = 6, h = arm_t);
            }
        }
        translate([0, 0, -1]) cylinder(r = neck_r + 0.15, h = plate_z + 1);
        translate([0, 0, -1]) cylinder(d = 6, h = plate_z + 10);                      // wires
        translate([-collar_r - 6, -1, -1]) cube([collar_r + 1, 2, plate_z + 0.5]);     // clamp slit
        translate([-collar_r - 1.5, -10, plate_z / 2]) rotate([-90, 0, 0]) cylinder(d = screw_d, h = 20);
        translate([-collar_r - 1.5, 3, plate_z / 2]) rotate([-90, 0, 0]) cylinder(r = nut_af / 2 / cos(30), h = 5, $fn = 6);
        translate([0, -30, axis_z]) rotate([-90, 0, 0]) cylinder(d = screw_d, h = 60);  // tilt bolt
    }
}

// ---------- head (head coordinates: origin bottom centre, lens towards -x) ----------
module head() {
    difference() {
        union() {
            difference() {
                translate([head_x[0], -hw, 0]) rounded_block(head_x[1] - head_x[0], 2 * hw, in_top + wall, 2);
                translate([cam_front, -head_in_w / 2, floor_z]) cube([head_x[1] - cam_front + 1, head_in_w, in_top - floor_z]);
            }
            translate([cam_front - 0.01, -(cam_sq + 0.4) / 2 - 1.6, cam_z - (cam_sq + 0.4) / 2 - 1.6])
                cube([cam_back - cam_front, cam_sq + 3.6, cam_sq + 3.6]);
            translate([head_x[1] - 6, 0, in_top - 3]) rotate([0, 90, 0]) cylinder(r = 3, h = 6.01);
            translate([head_x[1] - 6, -3, in_top - 3]) cube([6.01, 6, 3]);
        }
        translate([head_x[0] - 1, 0, cam_z]) rotate([0, 90, 0]) cylinder(d = lens_bore, h = cam_front - head_x[0] + 1.01);
        translate([head_x[0] - 0.01, 0, cam_z]) rotate([0, 90, 0]) cylinder(d1 = lens_bore + 2.4, d2 = lens_bore, h = 1.2);
        translate([cam_front - 0.02, -(cam_sq + 0.4) / 2, cam_z - (cam_sq + 0.4) / 2]) cube([cam_back - cam_front + 1, cam_sq + 0.4, cam_sq + 0.4]);
        // tilt bolt through the solid bottom, wire hole beside it, groove to the back
        translate([axis_hx, -hw - 1, axis_hz]) rotate([-90, 0, 0]) cylinder(d = screw_d, h = 2 * hw + 2);
        translate([3, 0, -1]) cylinder(d = 4, h = floor_z + 1);
        translate([3, -1.6, floor_z - 1.5]) cube([head_x[1] - 2, 3.2, 2]);
        for (z = [7.5, in_top - 3]) translate([head_x[1] - 8, 0, z]) rotate([0, 90, 0]) cylinder(d = pilot_d, h = 9);
    }
}
module rounded_block(l, w, h, r) {
    hull() for (x = [r, l - r], y = [r, w - r]) translate([x, y, 0]) cylinder(r = r, h = h);
}
module cover() {
    difference() {
        translate([head_x[1], -hw, 0]) cube([cover_t, 2 * hw, in_top + wall]);
        for (z = [7.5, in_top - 3]) translate([head_x[1] - 1, 0, z]) rotate([0, 90, 0]) {
            cylinder(d = screw_d, h = cover_t + 2);
            translate([0, 0, 1 + cover_t - 1.6]) cylinder(d1 = screw_d, d2 = 6.4, h = 1.61);
        }
    }
}
module retainer() {
    difference() {
        translate([ret_x[0], -head_in_w / 2 + 0.2, floor_z + 0.2]) cube([ret_x[1] - ret_x[0], head_in_w - 0.4, in_top - floor_z - 0.4]);
        translate([ret_x[0] - 1, -4, floor_z - 1]) cube([3.6, 8, cam_z - cam_sq / 2 - floor_z + 1.5]);
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
        // finger notches to lift the tower out (to charge, or to turn it off)
        for (s = [-1, 1]) translate([s * (W / 2 + 8), 8, 5]) scale([1, 1.6, 1]) cylinder(r = 9, h = 10);
    }
}

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
    if (show("wires_tower")) {
        top = wall + tp.y;
        wire([[-10, batt.y / 2, bot_h - 2], [tp_x1 - 4, tp_y + 3, top + 1], [tp_x1 - 4, tp_y + 1, top - 1]], "Red");
        wire([[10, batt.y / 2, bot_h - 2], [tp_x0 + 8, tp_y + 4, top + 2], [tp_x0 + 8, tp_y + 1, top - 1]], "Black");
        wire([[tp_x0 + 4, tp_y + 1, top - 1], [sw_x - 2.5, usb_y, wall + sw.z + 2]], "Red");
        wire([[sw_x + 2.5, usb_y, wall + sw.z + 2], [-0.6, D - 5, bot_h], [-0.6, D - 5, H - 2], [-0.6, pan_y, H - 1], [-0.6, pan_y, Ht + neck_h]], "Red");
        wire([[tp_x0 + 12, tp_y + 1, top - 1], [0.6, D - 5, bot_h], [0.6, D - 5, H - 2], [0.6, pan_y, H - 1], [0.6, pan_y, Ht + neck_h]], "Black");
    }
}
module head_contents() {
    if (show("xiao")) translate([xiao_x, -xiao[1] / 2, floor_z + 1.5]) {
        color("Black") cube([1.2, xiao[1] - 3, xiao[0] - 3]);
        color("Ivory") translate([-2.5, 1.5, xiao[0] - 7.5]) cube([2.5, xiao[1] - 6, 4]);
        color("DimGray") translate([xiao[2] - 1.2, 0, 0]) cube([1.2, xiao[1], xiao[0]]);
        color("Silver") translate([3, 2, 2]) cube([xiao[2] - 4.2, xiao[1] - 4, 10]);
        color("Silver") translate([xiao[2] - 4.4, xiao[1] / 2 - 4.5, -1.5]) cube([3.2, 9, 7]);
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
        wire([[2.4, 0, -6], [2.4, 0, floor_z - 0.8], [xiao_x + xiao[2] + 1, 0, floor_z - 0.8], [xiao_x + xiao[2] + 1, -1, floor_z + 9]], "Red");
        wire([[3.6, 0, -6], [3.6, 0, floor_z - 0.5], [xiao_x + xiao[2] + 1.5, 1, floor_z - 0.5], [xiao_x + xiao[2] + 1.5, 1.5, floor_z + 7]], "Black");
    }
}
// wires between the neck top and the head (turret coordinates, head level)
module turret_contents() {
    if (show("wires_turret")) {
        wire([[-0.6, 0, plate_z], [-3, 2, plate_z + 8], [-1, 0, axis_z - axis_hz + 1 - 6]], "Red");
        wire([[0.6, 0, plate_z], [-2, 3, plate_z + 8], [0, 0, axis_z - axis_hz + 1 - 6]], "Black");
    }
}

// ---------- placement ----------
// turret frame -> tower: on the pan axis at the crown top, head looking away from the wall
module at_turret() { translate([0, pan_y, Ht]) rotate(-90 + pan) children(); }
// head frame -> turret: tilt about the bolt
module at_head() { translate([0, 0, axis_z]) rotate([0, -tilt, 0]) translate([-axis_hx, 0, -axis_hz]) children(); }

module assembled(explode = 0, lid_on = true) {
    color("Gainsboro") tower();
    if (lid_on) color("Silver", 0.5) translate([0, -explode * 1.5, 0]) back();
    if (show_parts) translate([0, explode * 0.6, 0]) tower_contents();
    color("LightSteelBlue") translate([0, 0, explode * 2]) crown();
    if (show_foot) color("DimGray") translate([0, 0, -3 - explode * 1.5]) foot();
    translate([0, 0, explode * 3.5]) at_turret() {
        color("SlateGray") yoke();
        if (show_parts) turret_contents();
        translate([0, 0, explode * 1.2]) at_head() {
            color("Gainsboro") head();
            if (lid_on) color("Silver", 0.5) translate([explode * 2, 0, 0]) cover();
            color("Peru") translate([explode * 0.6, 0, 0]) retainer();
            if (show_parts) translate([explode * 1.2, 0, 0]) head_contents();
        }
    }
}
module cut(c) difference() { color(c) children(); color(c) translate([-200, -100, -50]) cube([200, 300, 400]); }

if (part == "tower") tower();
else if (part == "back") rotate([-90, 0, 0]) translate([0, pt, 0]) back();
else if (part == "crown") translate([0, 0, Ht]) rotate([180, 0, 0]) crown();
else if (part == "yoke") yoke();
else if (part == "head") rotate([0, -90, 0]) translate([-head_x[1], 0, 0]) head();
else if (part == "cover") rotate([0, -90, 0]) translate([-head_x[1], 0, 0]) cover();
else if (part == "retainer") rotate([0, 90, 0]) translate([-ret_x[0], 0, 0]) retainer();
else if (part == "foot") foot();
else if (part == "print_all") {
    tower();
    translate([W + 15, 0, 0]) rotate([-90, 0, 0]) translate([0, pt, 0]) back();
    translate([-W - 15, 0, Ht]) rotate([180, 0, 0]) crown();
    translate([-W - 15, -60, 0]) yoke();
    translate([0, -70, 0]) rotate([0, -90, 0]) translate([-head_x[1], 0, 0]) head();
    translate([50, -70, 0]) rotate([0, -90, 0]) translate([-head_x[1], 0, 0]) cover();
    translate([80, -70, 0]) rotate([0, 90, 0]) translate([-ret_x[0], 0, 0]) retainer();
    translate([0, -170, 0]) foot();
}
// pieces for the web viewer: tower ones in tower coordinates, yoke/turret ones in turret
// coordinates, head ones in head coordinates
else if (part == "x_tower") tower();
else if (part == "x_back") back();
else if (part == "x_crown") crown();
else if (part == "x_foot") translate([0, 0, -3]) foot();
else if (part == "x_yoke") yoke();
else if (part == "x_head") head();
else if (part == "x_cover") cover();
else if (part == "x_retainer") retainer();
else if (part == "x_tower_dummy") tower_contents();
else if (part == "x_turret_dummy") turret_contents();
else if (part == "x_head_dummy") head_contents();
else if (part == "inside") assembled(lid_on = false);
else if (part == "exploded") assembled(explode = 14);
else if (part == "section") {
    cut("Gainsboro") tower();
    cut("Silver") back();
    cut("LightSteelBlue") crown();
    if (show_foot) cut("DimGray") translate([0, 0, -3]) foot();
    at_turret() { cut("SlateGray") yoke(); at_head() { cut("Gainsboro") head(); cut("Silver") cover(); cut("Peru") retainer(); } }
    if (show_parts) { tower_contents(); at_turret() { turret_contents(); at_head() head_contents(); } }
}
else assembled();

echo(str("VIEWER {\"W\":", W, ",\"D\":", D, ",\"pt\":", pt, ",\"H\":", H, ",\"Ht\":", Ht, ",\"pan_y\":", pan_y,
         ",\"axis_z\":", axis_z, ",\"axis_hx\":", axis_hx, ",\"axis_hz\":", axis_hz, "}"));
