// ---------------------- 1. CORE DESIGN PARAMETERS ---------------------------
w = 1.8;                 // Channel width (mm)
h = 1.8;                 // Channel height (mm)
r0 = 10.0;               // Inner centerline radius (mm)
pitch = 2.2;             // Radial increase per turn (mm)
turns = 6;               // Number of complete turns
l_inlet = 2.0;           // Straight inlet length (mm)
l_outlet = 10.0;         // Straight outlet length (mm)

floor_t = 1.0;           // Solid floor under the channel (mm) 

// ---------------------- 2. SYRINGE PORT PARAMETERS --------------------------
tubing_od        = 1.59; // Tubing OD you will plug in (1/16" = 1.59 mm)
socket_clearance = -0.04;// Negative = slight press-fit. Use +0.05..0.1 if you
                         // plan to glue tubing, or if your printer over-extrudes
port_socket_d    = tubing_od + socket_clearance; // tubing socket diameter
port_hole_d      = 1.2;  // Flow hole from socket floor down into channel
                         // (must be < port_socket_d so tubing bottoms out)
boss_diameter    = 7.0;  // Raised boss OD (gives the tubing wall support)
boss_height      = 6.0;  // Boss height above chip top surface
socket_depth     = 6.5;  // Depth of tubing socket (from boss top downward)
leadin_height    = 1.0;  // Tapered lead-in at socket mouth
leadin_extra_d   = 1.6;  // Extra diameter at the very top of the lead-in

// ---------------------- 3. RESOLUTION ---------------------------------------
steps_per_turn = 120;
total_steps = turns * steps_per_turn;
PI = 3.141592653589793;
$fn = 64;                // Smoothness of the round port features

// ---------------------- 4. DERIVED PARAMETERS -------------------------------
k = pitch / (2 * PI);
r_outer = r0 + pitch * turns;
outer_edge_radius = r_outer + w / 2;

// ---------------------- 5. TANGENT ANGLE FUNCTION ---------------------------
function get_tangent_deg(theta_rad, r_val, k_val) =
    let(
        theta_deg = theta_rad * 180 / PI,
        dx = k_val * cos(theta_deg) - r_val * sin(theta_deg),
        dy = k_val * sin(theta_deg) + r_val * cos(theta_deg)
    )
    atan2(dy, dx);

// Helpers for the inlet / port location
function inlet_phi() = get_tangent_deg(0, r0, k);

// Free (upstream) end of the inlet
function inlet_end_xy() =
    [ r0 - l_inlet * cos(inlet_phi()),
      0  - l_inlet * sin(inlet_phi()) ];

// Inlet port: centred half a channel-width inside the free end of the inlet
function port_xy() =
    [ r0 - (l_inlet - w/2) * cos(inlet_phi()),
      0  - (l_inlet - w/2) * sin(inlet_phi()) ];

// Outlet port: centred half a channel-width inside the free end of the outlet
function outlet_phi() = get_tangent_deg(turns * 2 * PI, r_outer, k);
function outlet_port_xy() =
    [ r_outer + (l_outlet - w/2) * cos(outlet_phi()),
      0       + (l_outlet - w/2) * sin(outlet_phi()) ];

// ---------------------- 6. SPIRAL CHANNEL -----------------------------------
module spiral_channel()
{
    for (i = [0 : total_steps - 1])
    {
        t1 = (i / total_steps) * (turns * 2 * PI);
        t2 = ((i + 1) / total_steps) * (turns * 2 * PI);

        r1 = r0 + k * t1;
        r2 = r0 + k * t2;

        x1 = r1 * cos(t1 * 180 / PI);
        y1 = r1 * sin(t1 * 180 / PI);
        x2 = r2 * cos(t2 * 180 / PI);
        y2 = r2 * sin(t2 * 180 / PI);

        phi1 = get_tangent_deg(t1, r1, k);
        phi2 = get_tangent_deg(t2, r2, k);

        hull()
        {
            translate([x1, y1, h / 2]) rotate([0, 0, phi1])
                cube([0.05, w, h], center = true);
            translate([x2, y2, h / 2]) rotate([0, 0, phi2])
                cube([0.05, w, h], center = true);
        }
    }
}

// ---------------------- 7. STRAIGHT INLET -----------------------------------
module inlet_channel()
{
    phi_in = inlet_phi();
    x_center = r0 - (l_inlet / 2) * cos(phi_in);
    y_center = 0  - (l_inlet / 2) * sin(phi_in);

    translate([x_center, y_center, h / 2])
        rotate([0, 0, phi_in])
            cube([l_inlet, w, h], center = true);
}

// ---------------------- 8. STRAIGHT OUTLET ----------------------------------
module outlet_channel()
{
    t_out = turns * 2 * PI;
    r_out = r0 + k * t_out;
    x_out = r_out * cos(t_out * 180 / PI);
    y_out = r_out * sin(t_out * 180 / PI);
    phi_out = get_tangent_deg(t_out, r_out, k);

    x_center = x_out + (l_outlet / 2) * cos(phi_out);
    y_center = y_out + (l_outlet / 2) * sin(phi_out);

    translate([x_center, y_center, h / 2])
        rotate([0, 0, phi_out])
            cube([l_outlet, w, h], center = true);
}


module syringe_port_void(p, block_height = 5.0)
{
    top_z = block_height + boss_height;

    translate([p[0], p[1], 0])
    {
        // Flow hole: from mid-channel up to the socket floor
        translate([0, 0, floor_t + h / 2])
            cylinder(d = port_hole_d, h = top_z - (floor_t + h / 2) + 0.01);

        // Tubing socket
        translate([0, 0, top_z - socket_depth])
            cylinder(d = port_socket_d, h = socket_depth + 0.01);

        // Tapered lead-in
        translate([0, 0, top_z - leadin_height])
            cylinder(d1 = port_socket_d,
                     d2 = port_socket_d + leadin_extra_d,
                     h  = leadin_height + 0.01);
    }
}

module syringe_port_boss(p, block_height = 5.0)
{
    translate([p[0], p[1], 0])
        cylinder(d = boss_diameter, h = block_height + boss_height);
}

// ---------------------- 10. COMPLETE FLUID DOMAIN ---------------------------
module spiral_fluid_domain(block_height = 5.0)
{
    union()
    {
        // Channel is lifted by floor_t so the chip has a solid floor
        translate([0, 0, floor_t])
        {
            spiral_channel();
            inlet_channel();
            outlet_channel();
        }
        syringe_port_void(port_xy(), block_height);        // inlet (syringe)
        syringe_port_void(outlet_port_xy(), block_height); // outlet (collection)
    }
}

// ---------------------- 11. CHIP MOLD ---------------------------------------
module spiral_chip_mold(
    block_margin = 5.0,
    block_height = 5.0
)
{
    spiral_min_x = -outer_edge_radius;
    spiral_max_x =  outer_edge_radius;
    spiral_min_y = -outer_edge_radius;
    spiral_max_y =  outer_edge_radius;

    ie = inlet_end_xy();
    inlet_end_x = ie[0];
    inlet_end_y = ie[1];

    t_out = turns * 2 * PI;
    r_out = r0 + k * t_out;
    x_out = r_out * cos(t_out * 180 / PI);
    y_out = r_out * sin(t_out * 180 / PI);
    phi_out = get_tangent_deg(t_out, r_out, k);

    outlet_end_x = x_out + l_outlet * cos(phi_out);
    outlet_end_y = y_out + l_outlet * sin(phi_out);

    min_x = min(spiral_min_x, inlet_end_x) - w / 2 - block_margin;
    max_x = max(spiral_max_x, outlet_end_x) + w / 2 + block_margin;
    min_y = min(spiral_min_y, inlet_end_y) - w / 2 - block_margin;
    max_y = max(spiral_max_y, outlet_end_y) + w / 2 + block_margin;

    block_x = max_x - min_x;
    block_y = max_y - min_y;
    block_center_x = (min_x + max_x) / 2;
    block_center_y = (min_y + max_y) / 2;

    difference()
    {
        union()
        {
            translate([block_center_x, block_center_y, block_height / 2])
                cube([block_x, block_y, block_height], center = true);

            syringe_port_boss(port_xy(), block_height);         // inlet boss
            syringe_port_boss(outlet_port_xy(), block_height);  // outlet boss
        }

        spiral_fluid_domain(block_height);
    }
}

spiral_chip_mold();
