// Living-room camera enclosure - parametric OpenSCAD model (v2).
//
// Layout, bottom to top:
//   - battery bay: side ribs and end stops keep the pouch from sliding; a foam pad on
//     top of it is squeezed by the deck, so it can't rattle or jump in a fall
//   - deck: a separate plate over the battery (also keeps the warm electronics off
//     it). Four collars around the corner posts reach up to the lid, so screwing the
//     lid on clamps deck and battery down. The deck carries the XIAO standoffs, the
//     TP4056 pocket (USB-C out through the right wall) and the switch cradle.
//   - camera: the 75 mm flex module sits in a pocket in the front wall, behind the
//     lens hole, held by a slide-in retainer plate that the lid presses down.
// The box hangs in a cradle on two side hinges with radial teeth: it locks at any
// 10-degree step up/down when the M3 screws are tightened. The cradle turns left/right
// on a round foot, again on a tooth ring in 10-degree steps, clamped by a thumb knob
// reached through the windows in the foot. The foot stands on the shelf or screws to
// a wall through its two ears.
//
// Pick what to show/export with `part`, then Render (F6) and export STL.
// Print in PETG or ASA, 0.2 mm layers, 3 walls. Box upright (open side up), lid and
// deck flat, cradle on its base, retainer flat, foot on its ears, knob flat.
//
// Hardware: 4x M3x10 screws for the lid (self-tapping into the posts), 2x M3x16 +
// 2x M3 nuts (+ washers) for the hinges, 1x M3x16 socket-head screw + 1 nut for the
// swivel (the head is glued into the knob), a few strips of 1.5-2 mm foam tape.

part = "assembly";  // [assembly, inside, exploded, section, box, deck, lid, retainer, cradle, foot, knob, print_all]
tilt = 20;          // assembly preview only: degrees the lens looks down
pan = 0;            // assembly preview only: degrees turned to the left
show_parts = true;  // draw the electronics (grey-blue dummies) in the previews

/* [Contents - measured] */
batt = [110, 61, 14];     // battery: length incl. the sealed edge, width, max thickness
foam = 1.5;               // foam pad between battery and deck
gap_front = 9;            // in front of the battery: lid posts
gap_rear = 9;             // behind it: its tabs and wires, lid posts
side_clear = 1.5;         // each side of the battery (the ribs take 1 mm of it)
elec_h = 14;              // electronics layer above the deck

// XIAO ESP32S3 + Sense stack, camera connector towards the front
xiao = [21.5, 18, 10];
xiao_x = 34;              // its front edge, from the box front face
xiao_lift = 2;            // standoff height: room for the wires on the bottom pads
// TP4056 USB-C board: lies on the deck, receptacle end against the right wall
tp = [18.5, 25, 1.6];     // x (across), y (along, receptacle end at the wall), PCB
tp_usb_h = 3.2;           // receptacle height above the PCB
// slide switch, lying on its side, lever through the right wall
sw = [9, 3.5, 3];         // length, body height (towards the wall), thickness
sw_from_rear = 45;        // switch centre, from the rear outer face

/* [Shell] */
wall = 2.2;
lid_t = 2.2;
fit = 0.3;                // clearance for parts that drop into each other
corner_r = 3;
deck_t = 2;

/* [Camera module OV2640-75MM, from the maker's drawing] */
cam_sq = 8.5;             // square holder
cam_sq_d = 4.2;           // holder + sensor board depth
cam_len = 12.4;           // lens tip to the back of the board
lens_bore = 10.4;         // hole for the lens barrel (measured 10)
lens_recess = 0.5;        // lens tip sits this far behind the front face
cam_z = 27.5;             // lens centre above the box bottom
flex_w = 7.5;             // flex channel width

/* [Side openings] */
usb_w = 9.6;  usb_h = 4.0;        // TP4056 USB-C receptacle
plug_w = 12.5; plug_h = 7;        // outside recess for the cable plug's moulding
switch_slot = [5.5, 2.2];         // lever window (travel x height)

/* [Hinge] */
piv_x = 25;               // hinge axis distance from the front face
piv_z = 26;               // hinge axis height above the box bottom
teeth = 36;               // 36 teeth = 10-degree steps
ros_r_in = 3.6;
ros_r_out = 7.5;
ros_base = 0.8;
tooth_h = 1.2;
arm_t = 5;
arm_gap = 2.6;            // box side to arm: the tooth rings mesh with 0.2 mm left for the screw to pull in
piv_h = 44;               // hinge axis height above the cradle base: room to tilt
base_t = 5;
nut_af = 5.7;             // M3 nut across flats (+ clearance)
nut_depth = 2.6;
boss_r = 5;
boss_h = 3;

/* [Swivel] */
pan_dx = 35;              // swivel axis, behind the hinge axis (under the weight)
pan_r_in = 4;             // tooth ring under the cradle base / on top of the foot
pan_r_out = 14;
foot_r = 30;
foot_h = 16;
foot_top_t = 4;
knob_r = 11;
knob_h = 7;
head_d = 5.5;             // M3 socket head, press/glue fit in the knob

/* [Screws] */
post_r = 3.5;
pilot_d = 2.5;            // for M3 self-tapping into plastic
screw_d = 3.4;

$fn = 48;

// ---------- derived ----------
in_L = gap_front + batt.x + gap_rear;
in_W = batt.y + 2 * side_clear;
bay_top = wall + batt.z + foam;       // deck underside
deck_z = bay_top + deck_t;            // deck top
Hb = deck_z + elec_h;                 // box height without lid
Lo = in_L + 2 * wall;
Wo = in_W + 2 * wall;
batt_x = wall + gap_front;
post_in = post_r - 0.4;   // posts sink a little into the walls
posts = [for (x = [wall + post_in, Lo - wall - post_in], y = [wall + post_in, Wo - wall - post_in]) [x, y]];
collar_r = post_r + 2;

// swivel
base_top = piv_z - piv_h;                       // cradle base, top face
base_bot = base_top - base_t;
pan_x = piv_x + pan_dx;
pan_y = Wo / 2;
foot_top = base_bot - 2 * ros_base - tooth_h;   // the two tooth rings fully meshed
foot_bot = foot_top - foot_h;

// camera block geometry (x measured from the front face)
cam_front = lens_recess + cam_len - cam_sq_d;   // front of the square holder
cam_back = lens_recess + cam_len;               // back of the sensor board
ret_t = 1.6;                                    // retainer plate
blk_back = cam_back + ret_t + 0.4 + 1.6;
blk_w = cam_sq + 2 * 2.6;
blk_z0 = cam_z - cam_sq / 2 - 3;                // bottom of the block's square part
slot_floor = cam_z - cam_sq / 2 - 1;            // retainer rests here, either side of the flex

// TP4056 and switch placement
tp_x1 = Lo - wall - post_r - collar_r - 0.6;    // rear edge, clear of the rear collar
tp_x0 = tp_x1 - tp.x;
usb_z = deck_z + tp.z + tp_usb_h / 2;
sw_x = Lo - sw_from_rear;
sw_z = deck_z + 1 + sw.z / 2;

// ---------- helpers ----------
module rounded_block(l, w, h, r) {
    hull() for (x = [r, l - r], y = [r, w - r]) translate([x, y, 0]) cylinder(r = r, h = h);
}

// Rounded slot centred on the origin in XY, extruded along +Z.
module slot(w, h, depth) {
    hull() for (x = [-(w - h) / 2, (w - h) / 2]) translate([x, 0, 0]) cylinder(d = h, h = depth);
}

// One tooth runs radially along +X from r_in to r_out; triangle cross-section,
// base on z=0, ridge at z=tooth_h.
module tooth(r_in, r_out) {
    w = 2 * PI * (r_in + r_out) / 2 / teeth;
    translate([r_in, 0, 0]) rotate([0, 90, 0])
        linear_extrude(r_out - r_in)
            polygon([[0, -w / 2], [0, w / 2], [-tooth_h, 0]]);
}

// Toothed ring in the XY plane, teeth pointing +Z.
module rosette(r_in = ros_r_in, r_out = ros_r_out) {
    difference() {
        union() {
            cylinder(r = r_out, h = ros_base);
            translate([0, 0, ros_base]) for (i = [0 : teeth - 1]) rotate(i * 360 / teeth) tooth(r_in, r_out);
        }
        translate([0, 0, -1]) cylinder(r = r_in, h = ros_base + tooth_h + 2);
    }
}

// ---------- box ----------
module camera_block() {
    // square part, with a 45-degree underside down the front wall so it prints
    // without supports; cut back where the battery goes
    difference() {
        hull() {
            translate([wall - 0.01, Wo / 2 - blk_w / 2, blk_z0]) cube([blk_back - wall, blk_w, Hb - blk_z0]);
            translate([wall - 0.01, Wo / 2 - blk_w / 2, blk_z0 - (blk_back - wall)]) cube([0.01, blk_w, 1]);
        }
        translate([batt_x - 0.5, 0, 0]) cube([Lo, Wo, bay_top + 0.5]);
    }
}

module camera_cuts() {
    cy = Wo / 2;
    // lens barrel hole, and a chamfer so the 120-degree view isn't clipped
    translate([-1, cy, cam_z]) rotate([0, 90, 0]) cylinder(d = lens_bore, h = cam_front + 1.01);
    translate([-0.01, cy, cam_z]) rotate([0, 90, 0]) cylinder(d1 = lens_bore + 2.4, d2 = lens_bore, h = 1.2);
    // square pocket for the holder, open up to the top so the module drops in
    translate([cam_front, cy - (cam_sq + 0.4) / 2, cam_z - (cam_sq + 0.4) / 2])
        cube([cam_back - cam_front + 0.2, cam_sq + 0.4, Hb]);
    // retainer slot (full width, open at the top) ...
    translate([cam_back + 0.2, cy - blk_w / 2 - 1, slot_floor]) cube([ret_t + 0.4, blk_w + 2, Hb]);
    // ... and the flex channel straight down from the bottom of the sensor board
    translate([cam_back - 1.2, cy - flex_w / 2, 0]) cube([ret_t + 1.8, flex_w, cam_z]);
}

module box() {
    difference() {
        union() {
            difference() {
                rounded_block(Lo, Wo, Hb, corner_r);
                translate([wall, wall, wall]) rounded_block(in_L, in_W, Hb, max(0.5, corner_r - wall));
            }
            // lid screw posts in the corners
            for (p = posts) translate([p.x, p.y, 0]) cylinder(r = post_r, h = Hb);
            // battery: ribs along both sides ...
            for (x = [batt_x + 15, batt_x + batt.x / 2, batt_x + batt.x - 15], y = [wall, Wo - wall])
                translate([x, y, wall]) rotate([0, 0, y > Wo / 2 ? 180 : 0])
                    linear_extrude(batt.z - 1) polygon([[-2, -0.01], [2, -0.01], [0.6, 1], [-0.6, 1]]);
            // ... an end stop wall in front, two low stops at the tab end
            translate([batt_x - 1.6, wall + post_r * 2 + 1, wall - 0.01]) cube([1.6, in_W - post_r * 4 - 2, 10]);
            for (y = [wall, Wo - wall - 10])
                translate([batt_x + batt.x + 0.5, y, wall - 0.01]) cube([1.6, 10, 5]);
            // ledges the deck rests on
            for (y = [wall - 0.01, Wo - wall - 1.2 + 0.01])
                translate([batt_x, y, bay_top - 3]) hull() {
                    translate([0, 0, 2]) cube([batt.x, 1.2, 1]);
                    translate([0, y < Wo / 2 ? 0 : 1.19, 0]) cube([batt.x, 0.01, 0.01]);
                }
            // hinge bosses inside the side walls: they hold the nuts
            translate([piv_x, wall - 0.01, piv_z]) rotate([-90, 0, 0]) cylinder(r = boss_r, h = boss_h);
            translate([piv_x, Wo - wall + 0.01, piv_z]) rotate([90, 0, 0]) cylinder(r = boss_r, h = boss_h);
            // tooth rings on the outside
            translate([piv_x, 0.2, piv_z]) rotate([90, 0, 0]) rosette();
            translate([piv_x, Wo - 0.2, piv_z]) rotate([-90, 0, 0]) rosette();
            camera_block();
        }
        camera_cuts();
        // hinge screw holes and nut traps
        translate([piv_x, -5, piv_z]) rotate([-90, 0, 0]) cylinder(d = screw_d, h = Wo + 10);
        translate([piv_x, wall + boss_h - nut_depth, piv_z]) rotate([-90, 0, 0])
            cylinder(r = nut_af / 2 / cos(30), h = nut_depth + 0.1, $fn = 6);
        translate([piv_x, Wo - wall - boss_h - 0.1, piv_z]) rotate([-90, 0, 0])
            cylinder(r = nut_af / 2 / cos(30), h = nut_depth + 0.1, $fn = 6);
        // USB-C (right side = y max), with a recess for the plug outside
        translate([(tp_x0 + tp_x1) / 2, Wo - wall - 1, usb_z]) rotate([-90, 0, 0]) slot(usb_w, usb_h, wall + 2);
        translate([(tp_x0 + tp_x1) / 2, Wo - 1, usb_z]) rotate([-90, 0, 0]) slot(plug_w, plug_h, 2);
        // switch lever window
        translate([sw_x - switch_slot.x / 2, Wo - wall - 1, sw_z - switch_slot.y / 2]) cube([switch_slot.x, wall + 2, switch_slot.y]);
        // lid screw pilot holes
        for (p = posts) translate([p.x, p.y, Hb - 12]) cylinder(d = pilot_d, h = 13);
    }
}

// ---------- deck ----------
module deck() {
    xiao_y = Wo / 2 - xiao.y / 2;
    difference() {
        union() {
            // plate, with chamfered corners
            translate([wall + fit, wall + fit, bay_top]) linear_extrude(deck_t)
                offset(delta = 1, chamfer = true) offset(delta = -1) square([in_L - 2 * fit, in_W - 2 * fit]);
            // collars around the posts, up to the lid
            for (p = posts) translate([p.x, p.y, bay_top]) intersection() {
                cylinder(r = collar_r, h = Hb - bay_top);
                translate([wall + fit - p.x, wall + fit - p.y, 0]) cube([in_L - 2 * fit, in_W - 2 * fit, Hb]);
            }
            // XIAO: four corner guards with a shelf, wires pass between them
            for (cx = [0, 1], cy = [0, 1]) translate([xiao_x + cx * xiao.x, xiao_y + cy * xiao.y, deck_z - 0.01])
                mirror([cx, 0, 0]) mirror([0, cy, 0]) difference() {
                    translate([-1.4, -1.4, 0]) cube([5.4, 5.4, xiao_lift + 4]);
                    translate([0, 0, xiao_lift]) cube([10, 10, 10]);
                }
            // TP4056: rails on both long edges, stops at the inner end (pads stay free)
            for (x = [tp_x0 - 1.4 - fit, tp_x1 + fit]) translate([x, Wo - wall - fit - tp.y - 1.5, deck_z - 0.01])
                cube([1.4, tp.y + 1.5 - 0.01, tp.z + 1.4]);
            for (x = [tp_x0 - 1.4 - fit, tp_x1 - 3 + fit]) translate([x, Wo - wall - fit - tp.y - 1.5 - fit, deck_z - 0.01])
                cube([4.4, 1.5, tp.z + 1.4]);
            // switch cradle against the right wall
            translate([sw_x - sw.x / 2 - 1.4 - fit, Wo - wall - fit - sw.y - 1.4 - fit, deck_z - 0.01])
                difference() {
                    cube([sw.x + 2.8 + 2 * fit, sw.y + 1.4 + 2 * fit, 1 + sw.z]);
                    translate([1.4, 1.4, 1]) cube([sw.x + 2 * fit, sw.y + 1, sw.z + 1]);
                    translate([1.4 + 1.5, -1, 1]) cube([sw.x + 2 * fit - 3, 3, sw.z + 1]);  // pins
                }
        }
        // post holes
        for (p = posts) translate([p.x, p.y, 0]) cylinder(r = post_r + 0.3, h = Hb + 1);
        // notches so it drops past the camera block and the hinge bosses
        translate([0, Wo / 2 - blk_w / 2 - fit, 0]) cube([blk_back + fit, blk_w + 2 * fit, Hb]);
        for (y = [0, Wo - wall - boss_h - fit]) translate([piv_x - boss_r - fit, y, 0]) cube([2 * boss_r + 2 * fit, wall + boss_h + fit, Hb]);
        // battery wires come up behind the TP4056
        translate([Lo - wall - gap_rear - 4, Wo / 2 + 4, 0]) cube([gap_rear + 4 - post_r, 16, Hb]);
        // the camera flex goes down past the deck edge behind the block
        translate([blk_back - 1, Wo / 2 - flex_w / 2 - 1, 0]) cube([6, flex_w + 2, Hb]);
    }
}

// ---------- camera retainer ----------
module retainer() {
    h = Hb - slot_floor - 0.2;
    difference() {
        cube([ret_t, blk_w + 1.6, h]);
        translate([-1, (blk_w + 1.6 - flex_w - 0.6) / 2, -1]) cube([ret_t + 2, flex_w + 0.6, 3]);   // flex
        translate([-1, (blk_w + 1.6) / 2 - 2, h - 2]) cube([ret_t + 2, 4, 3]);                          // grip
    }
}
module retainer_placed() { translate([cam_back + 0.4, Wo / 2 - (blk_w + 1.6) / 2, slot_floor]) retainer(); }

// ---------- lid ----------
// Modelled in place: plate from z=0 up, pressers hanging below. Printed flipped.
module lid() {
    xiao_top = deck_z + xiao_lift + xiao.z;
    difference() {
        union() {
            rounded_block(Lo, Wo, lid_t, corner_r);
            // presser over the XIAO's rear half (put a foam square under it)
            translate([xiao_x + xiao.x / 2, Wo / 2 - 5, -(Hb - xiao_top - 2) + 0.01]) cube([8, 10, Hb - xiao_top - 2]);
            // presser on the TP4056 USB receptacle
            translate([(tp_x0 + tp_x1) / 2 - 4, Wo - wall - fit - 7, -(Hb - usb_z - tp_usb_h / 2 - 0.2) + 0.01])
                cube([8, 6, Hb - usb_z - tp_usb_h / 2 - 0.2]);
            // presser on the switch
            translate([sw_x - 3, Wo - wall - fit - sw.y, -(Hb - deck_z - 1 - sw.z - 0.2) + 0.01])
                cube([6, sw.y - 0.5, Hb - deck_z - 1 - sw.z - 0.2]);
        }
        // countersunk screw holes
        for (p = posts) translate([p.x, p.y, -1]) {
            cylinder(d = screw_d, h = lid_t + 2);
            translate([0, 0, 1 + lid_t - 1.7]) cylinder(d1 = screw_d, d2 = 6.4, h = 1.71);
        }
        // vents over the XIAO and over the charger
        for (i = [0 : 3]) translate([xiao_x + 1 + i * 5, Wo / 2 - 14, -1]) cube([2, 7, lid_t + 2]);
        for (i = [0 : 3]) translate([xiao_x + 1 + i * 5, Wo / 2 + 7, -1]) cube([2, 7, lid_t + 2]);
        for (i = [0 : 3]) translate([tp_x0 + 1 + i * 4.5, Wo - wall - 24, -1]) cube([2, 14, lid_t + 2]);
        // shallow recess underneath for the flat Wi-Fi antenna, front-left
        translate([wall + 12, wall + 2, -0.01]) cube([45, 12, 0.6]);
    }
}

// ---------- cradle ----------
module cradle() {
    y0 = -arm_gap - arm_t;
    y1 = Wo + arm_gap;
    difference() {
        union() {
            // base plate, mostly behind the hinge where the weight sits; short in
            // front so it stays out of the picture when looking down
            translate([piv_x - 12, y0, base_top - base_t]) rounded_block(92, y1 + arm_t - y0, base_t, 4);
            // arms
            for (y = [y0, y1]) hull() {
                translate([piv_x - 10, y, base_top - 0.01]) cube([28, arm_t, 1]);
                translate([piv_x, y, piv_z]) rotate([-90, 0, 0]) cylinder(r = ros_r_out + 1.5, h = arm_t);
            }
            // tooth rings facing the box
            translate([piv_x, -arm_gap - 0.2, piv_z]) rotate([-90, 0, 0]) rosette();
            translate([piv_x, Wo + arm_gap + 0.2, piv_z]) rotate([90, 0, 0]) rosette();
            // swivel tooth ring underneath, facing the foot
            translate([pan_x, pan_y, base_bot + 0.2]) mirror([0, 0, 1]) rosette(pan_r_in, pan_r_out);
        }
        translate([piv_x, y0 - 1, piv_z]) rotate([-90, 0, 0]) cylinder(d = screw_d, h = y1 + arm_t - y0 + 2);
        // swivel screw, nut trap in the top face
        translate([pan_x, pan_y, base_bot - 5]) cylinder(d = screw_d, h = base_t + 10);
        translate([pan_x, pan_y, base_top - nut_depth]) cylinder(r = nut_af / 2 / cos(30), h = nut_depth + 1, $fn = 6);
    }
}

// ---------- swivel foot and knob ----------
module foot() {
    ear_y = foot_r + 9;
    difference() {
        union() {
            translate([pan_x, pan_y, foot_bot]) cylinder(r = foot_r, h = foot_h);
            translate([pan_x, pan_y, foot_top - 0.2]) rosette(pan_r_in, pan_r_out);
            // ears for a wall (or just feet on the shelf)
            hull() for (y = [-ear_y, ear_y]) translate([pan_x, pan_y + y, foot_bot]) cylinder(r = 7, h = 4);
        }
        // hollow inside, open at the bottom, with two windows to reach the knob
        translate([pan_x, pan_y, foot_bot - 1]) cylinder(r = foot_r - 3, h = foot_h - foot_top_t + 1);
        for (a = [0, 180]) translate([pan_x, pan_y, foot_bot + 4]) rotate(a)
            translate([0, -foot_r * 0.55, 0]) cube([foot_r + 1, foot_r * 1.1, foot_h - foot_top_t - 4]);
        translate([pan_x, pan_y, foot_top - foot_top_t - 1]) cylinder(d = screw_d, h = foot_top_t + 4);
        // countersunk ear holes
        for (y = [-ear_y, ear_y]) translate([pan_x, pan_y + y, foot_bot - 0.01]) {
            cylinder(d = 4.5, h = 5);
            translate([0, 0, 1.5]) cylinder(d1 = 4.5, d2 = 9, h = 2.52);
        }
    }
}

// Thumb knob: the M3 screw head is glued into it from the top; turning it pulls the
// cradle down onto the foot. Modelled in place, top face against the foot.
module knob() {
    z1 = foot_top - foot_top_t;
    translate([pan_x, pan_y, z1 - knob_h]) difference() {
        union() {
            cylinder(r = knob_r - 1, h = knob_h);
            for (i = [0 : 11]) rotate(i * 30) translate([knob_r - 1.2, 0, 0]) cylinder(r = 1.5, h = knob_h);
        }
        translate([0, 0, -1]) cylinder(d = screw_d, h = knob_h + 2);
        translate([0, 0, knob_h - 3.2]) cylinder(d = head_d, h = 4);
    }
}

// ---------- dummies of the parts that go inside (preview only) ----------
// level: 0 = battery bay, 1 = on the deck, 2 = under the lid. `only` limits it to
// one group (for exporting the dummies one by one).
only = "";
function show(n) = only == "" || only == n;
module contents(level) {
    xiao_y = Wo / 2 - xiao.y / 2;
    xz = deck_z + xiao_lift;
    if (level == 0) {
    // battery, foam on top, tabs at the rear
    if (show("battery")) color("RoyalBlue") translate([batt_x + 0.5, wall + side_clear, wall]) cube([batt.x - 1, batt.y, batt.z - 0.5]);
    if (show("foam")) color("LightYellow") translate([batt_x + 10, wall + side_clear + 5, wall + batt.z - 0.5]) cube([batt.x - 20, batt.y - 10, foam]);
    // camera module in its pocket
    if (show("camera")) translate([lens_recess, Wo / 2, cam_z]) {
        color("Black") rotate([0, 90, 0]) cylinder(d = 8, h = cam_len - cam_sq_d);
        color("Black") translate([cam_len - cam_sq_d, -cam_sq / 2, -cam_sq / 2]) cube([cam_sq_d - 0.3, cam_sq, cam_sq]);
        color("SteelBlue") translate([cam_len - 0.3, -cam_sq / 2, -cam_sq / 2]) cube([0.3, cam_sq, cam_sq]);
    }
    if (show("battery")) color("Silver") for (dy = [18, 38]) translate([batt_x + batt.x - 0.5, wall + side_clear + dy, wall + batt.z / 2]) cube([4, 5, 0.3]);
    }
    if (level == 1) {
    // XIAO (bottom board with castellations) + Sense board + flex connector
    if (show("xiao")) translate([xiao_x, xiao_y, xz]) {
        color("DimGray") cube([xiao.x, xiao.y, 1.2]);
        color("Silver") translate([xiao.x - 7, xiao.y / 2 - 4.5, 1.2]) cube([8.5, 9, 3.2]);   // USB-C
        color("Silver") translate([8, 3, 1.2]) cube([10, 12, 2.4]);                           // shield
        color("Black") translate([0, 0, 4]) cube([xiao.x - 3, xiao.y, 1.2]);                  // Sense board
        color("Ivory") translate([0.5, 1.5, 5.2]) cube([4, xiao.y - 3, 2.5]);                 // FPC connector
        color("DarkGoldenrod") translate([2, xiao.y / 2 - 6, 9.6]) cube([2.5, 12, 0.4]);     // U.FL antenna plug
    }
    // its flex: down the channel, back along the deck, up into the XIAO connector
    if (show("flex")) color("Orange") {
        fx = cam_back + 0.3; fz = deck_z + 0.6;
        translate([fx - 0.3, Wo / 2 - 3, fz]) cube([0.3, 6, cam_z - cam_sq / 2 - fz]);
        translate([fx - 0.3, Wo / 2 - 3, fz]) cube([xiao_x - fx - 3, 6, 0.3]);
        translate([xiao_x - 3.3, Wo / 2 - 3, fz]) cube([0.3, 6, xz + 6.5 - fz]);
        translate([xiao_x - 3.3, Wo / 2 - 3, xz + 6.5]) cube([5, 6, 0.3]);
    }
    // TP4056: PCB, USB-C receptacle at the wall, two LEDs
    if (show("tp4056")) translate([tp_x0, Wo - wall - tp.y, deck_z]) {
        color("MediumBlue") cube([tp.x, tp.y, tp.z]);
        color("Silver") translate([tp.x / 2 - 4.5, tp.y - 7.3, tp.z]) cube([9, 9.3, tp_usb_h]);
        color("Black") translate([tp.x / 2 - 2.5, 7, tp.z]) cube([5, 5, 1.5]);
    }
    // switch: body, pins, lever through the wall
    if (show("switch")) translate([sw_x - sw.x / 2, Wo - wall - sw.y, deck_z + 1]) {
        color("Black") cube([sw.x, sw.y, sw.z]);
        color("Silver") for (i = [0 : 2]) translate([1.5 + i * 2.5, -1.5, sw.z / 2]) cube([0.5, 1.5, 0.3]);
        color("WhiteSmoke") translate([sw.x / 2 - 0.75, sw.y, sw.z / 2 - 0.75]) cube([1.5, 3, 1.5]);
    }
    }
    // flat Wi-Fi antenna stuck under the lid
    if (level == 2 && show("antenna")) color("Tan") translate([wall + 12.5, wall + 2.5, Hb - 0.2]) cube([44, 11, 0.2]);
    // wires: battery tabs -> TP4056 B+/B-, TP4056 OUT -> switch -> XIAO BAT pads
    module wire(pts, c) color(c) for (i = [0 : len(pts) - 2]) hull() {
        translate(pts[i]) sphere(d = 1.2, $fn = 8);
        translate(pts[i + 1]) sphere(d = 1.2, $fn = 8);
    }
    if (level == 1 && show("wires")) {
    rx = batt_x + batt.x + 2.5;
    wire([[rx, wall + side_clear + 20, wall + 7], [rx, Wo / 2 + 9, deck_z + 1], [tp_x0 + 4, Wo - wall - tp.y + 2, deck_z + 2]], "Red");
    wire([[rx, wall + side_clear + 40, wall + 7], [rx + 1, Wo / 2 + 13, deck_z + 1], [tp_x0 + 8, Wo - wall - tp.y + 2, deck_z + 2]], "Black");
    wire([[tp_x0 + 12, Wo - wall - tp.y + 2, deck_z + 2], [sw_x + 2.5, Wo - wall - sw.y - 1.5, sw_z]], "Red");
    wire([[sw_x, Wo - wall - sw.y - 1.5, sw_z], [xiao_x + xiao.x - 4, xiao_y + 4, xz - 0.5]], "Red");
    wire([[tp_x0 + 15, Wo - wall - tp.y + 2, deck_z + 2], [xiao_x + xiao.x - 4, xiao_y + 8, xz - 0.5]], "Black");
    }
}

// ---------- output ----------
// Section helper: each part is cut on its own so the cut faces keep its colour.
module cut(c) difference() { color(c) children(); color(c) translate([-10, -10, -10]) cube([Lo + 20, Wo / 2 + 10, Hb + 20]); }

module lid_print() { translate([0, Wo, lid_t]) rotate([180, 0, 0]) lid(); }
module deck_print() { translate([0, 0, -bay_top]) deck(); }

module assembled(lid_on = true, explode = 0) {
    color("Gainsboro") box();
    color("LightSteelBlue") translate([0, 0, explode * 2]) deck();
    color("Peru") translate([0, 0, explode * 4]) retainer_placed();
    if (show_parts) {
        translate([0, 0, explode * 1]) contents(0);
        translate([0, 0, explode * 2]) contents(1);
        if (lid_on) translate([0, 0, explode * 5]) contents(2);
    }
    if (lid_on) color("Silver", 0.45) translate([0, 0, Hb + explode * 5]) lid();
}

if (part == "box") box();
else if (part == "deck") deck_print();
else if (part == "lid") lid_print();
else if (part == "retainer") rotate([0, -90, 0]) retainer();
else if (part == "cradle") translate([0, 0, -base_bot]) cradle();
else if (part == "foot") translate([0, 0, -foot_bot]) foot();
else if (part == "knob") knob();
// pieces in assembly position, for the web viewer
else if (part == "x_box") box();
else if (part == "x_deck") deck();
else if (part == "x_lid") translate([0, 0, Hb]) lid();
else if (part == "x_retainer") retainer_placed();
else if (part == "x_cradle") cradle();
else if (part == "x_foot") foot();
else if (part == "x_knob") knob();
else if (part == "x_dummy") for (l = [0 : 2]) contents(l);
else if (part == "print_all") {
    box();
    translate([0, Wo + 10, 0]) lid_print();
    translate([0, 2 * Wo + 20, 0]) deck_print();
    translate([Lo + 10, 0, 0]) rotate([0, -90, 0]) retainer();
    translate([0, -Wo - 30, -base_bot]) cradle();
    translate([Lo + 50 - pan_x, -Wo - 30 - pan_y + 30, -foot_bot]) foot();
    translate([Lo + 50 - pan_x, 2 * Wo - pan_y, 0]) knob();
}
else if (part == "inside") assembled(lid_on = false);
else if (part == "exploded") assembled(explode = 14);
else if (part == "section") {
    cut("Gainsboro") box();
    cut("LightSteelBlue") deck();
    cut("Peru") retainer_placed();
    cut("Silver") translate([0, 0, Hb]) lid();
    if (show_parts) for (l = [0 : 2]) contents(l);
}
else {
    color("DimGray") foot();
    color("Peru") knob();
    translate([pan_x, pan_y, 0]) rotate(pan) translate([-pan_x, -pan_y, 0]) {
        color("SlateGray") cradle();
        translate([piv_x, 0, piv_z]) rotate([0, -tilt, 0]) translate([-piv_x, 0, -piv_z]) assembled();
    }
}
echo(str("VIEWER {\"piv_x\":", piv_x, ",\"piv_z\":", piv_z, ",\"pan_x\":", pan_x, ",\"pan_y\":", pan_y,
         ",\"Lo\":", Lo, ",\"Wo\":", Wo, ",\"Hb\":", Hb, ",\"lid_t\":", lid_t, ",\"foot_bot\":", foot_bot, "}"));
