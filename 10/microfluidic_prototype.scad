// ============================================================================
// 6-TURN SPIRAL MICROFLUIDIC CHANNEL
// ============================================================================
// Units: millimeters (mm)
//
// DESIGN:
//   Channel cross-section:       1.8 mm × 1.8 mm
//   Hydraulic diameter:          1.8 mm
//   Number of complete turns:    6
//   Inner centerline radius:     10.0 mm
//   Pitch:                       2.2 mm / turn
//   Final centerline radius:     23.2 mm
//   Inlet length:                2.0 mm
//   Outlet length:               10.0 mm
//   Outlet:                      Continuous / no divider
//
// ============================================================================


// ============================================================================
// 1. CORE DESIGN PARAMETERS
// ============================================================================

w = 1.8;                 // Channel width (mm)
h = 1.8;                 // Channel height (mm)

r0 = 10.0;               // Inner centerline radius (mm)
pitch = 2.2;             // Radial increase per complete turn (mm)

turns = 6;               // Number of complete turns

l_inlet = 2.0;           // Straight inlet length (mm)
l_outlet = 10.0;         // Straight outlet length (mm)


// ============================================================================
// 2. RESOLUTION
// ============================================================================
//
// 120 segments per turn = 3 degrees per segment.
// Increase to 180 or 240 if you want a smoother STL.
//

steps_per_turn = 120;
total_steps = turns * steps_per_turn;

PI = 3.141592653589793;


// ============================================================================
// 3. DERIVED PARAMETERS
// ============================================================================

// Archimedean spiral:
//
//     r(theta) = r0 + k*theta
//
// where:
//
//     k = pitch / (2*pi)
//
// Therefore, after six complete turns:
//
//     r_final = 10.0 + (2.2 * 6)
//             = 23.2 mm

k = pitch / (2 * PI);

r_outer = r0 + pitch * turns;


// Physical outer edge of the channel.

outer_edge_radius = r_outer + w / 2;


// ============================================================================
// 4. TANGENT ANGLE FUNCTION
// ============================================================================
//
// For:
//
//     r(theta) = r0 + k*theta
//
// The tangent vector is:
//
//     dx/dtheta = k*cos(theta) - r*sin(theta)
//     dy/dtheta = k*sin(theta) + r*cos(theta)
//
// OpenSCAD trig functions use degrees.
//

function get_tangent_deg(theta_rad, r_val, k_val) =
    let(
        theta_deg = theta_rad * 180 / PI,

        dx =
            k_val * cos(theta_deg)
            - r_val * sin(theta_deg),

        dy =
            k_val * sin(theta_deg)
            + r_val * cos(theta_deg)
    )
    atan2(dy, dx);


// ============================================================================
// 5. SPIRAL CHANNEL
// ============================================================================
//
// Creates the continuous 3D fluid channel.
//
// The spiral:
//
//     starts at radius 10.0 mm
//
//     makes 6 complete revolutions
//
//     ends at radius 23.2 mm
//
// Each small section is tangent-aligned.
// Hull() connects neighboring sections.
//
// ============================================================================

module spiral_channel()
{
    for (i = [0 : total_steps - 1])
    {

        // ------------------------------------------------------------
        // Angular positions
        // ------------------------------------------------------------

        t1 =
            (i / total_steps)
            * (turns * 2 * PI);

        t2 =
            ((i + 1) / total_steps)
            * (turns * 2 * PI);


        // ------------------------------------------------------------
        // Radius
        // ------------------------------------------------------------

        r1 = r0 + k * t1;
        r2 = r0 + k * t2;


        // ------------------------------------------------------------
        // Cartesian coordinates
        // ------------------------------------------------------------

        x1 =
            r1 * cos(t1 * 180 / PI);

        y1 =
            r1 * sin(t1 * 180 / PI);

        x2 =
            r2 * cos(t2 * 180 / PI);

        y2 =
            r2 * sin(t2 * 180 / PI);


        // ------------------------------------------------------------
        // Local tangent directions
        // ------------------------------------------------------------

        phi1 =
            get_tangent_deg(
                t1,
                r1,
                k
            );

        phi2 =
            get_tangent_deg(
                t2,
                r2,
                k
            );


        // ------------------------------------------------------------
        // Connect adjacent sections
        // ------------------------------------------------------------

        hull()
        {
            translate([
                x1,
                y1,
                h / 2
            ])
                rotate([
                    0,
                    0,
                    phi1
                ])
                    cube([
                        0.05,
                        w,
                        h
                    ], center = true);


            translate([
                x2,
                y2,
                h / 2
            ])
                rotate([
                    0,
                    0,
                    phi2
                ])
                    cube([
                        0.05,
                        w,
                        h
                    ], center = true);
        }
    }
}


// ============================================================================
// 6. STRAIGHT 2-MM INLET
// ============================================================================
//
// The inlet is attached to the beginning of the spiral.
//
// Spiral starting point:
//
//     (10.0, 0)
//
// The inlet extends backward along the reverse tangent.
//
// Length:
//
//     2.0 mm
//
// ============================================================================

module inlet_channel()
{
    t_in = 0;

    r_in = r0;

    x_in = r_in;
    y_in = 0;


    phi_in =
        get_tangent_deg(
            t_in,
            r_in,
            k
        );


    // Move backward from the spiral starting point.

    x_center =
        x_in
        - (l_inlet / 2)
        * cos(phi_in);

    y_center =
        y_in
        - (l_inlet / 2)
        * sin(phi_in);


    translate([
        x_center,
        y_center,
        h / 2
    ])
        rotate([
            0,
            0,
            phi_in
        ])
            cube([
                l_inlet,
                w,
                h
            ], center = true);
}


// ============================================================================
// 7. STRAIGHT 10-MM OUTLET
// ============================================================================
//
// The outlet begins at the end of the 6th complete turn.
//
// Final spiral point:
//
//     theta = 12*pi
//     radius = 23.2 mm
//
// Since 6 complete turns return to the positive X direction,
// the outlet extends generally to the right/up according to
// the true local tangent.
//
// ============================================================================

module outlet_channel()
{
    t_out =
        turns * 2 * PI;


    r_out =
        r0 + k * t_out;


    x_out =
        r_out
        * cos(t_out * 180 / PI);

    y_out =
        r_out
        * sin(t_out * 180 / PI);


    phi_out =
        get_tangent_deg(
            t_out,
            r_out,
            k
        );


    // Extend forward along the tangent.

    x_center =
        x_out
        + (l_outlet / 2)
        * cos(phi_out);

    y_center =
        y_out
        + (l_outlet / 2)
        * sin(phi_out);


    translate([
        x_center,
        y_center,
        h / 2
    ])
        rotate([
            0,
            0,
            phi_out
        ])
            cube([
                l_outlet,
                w,
                h
            ], center = true);
}


// ============================================================================
// 8. COMPLETE CONTINUOUS FLUID DOMAIN
// ============================================================================

module spiral_fluid_domain()
{
    union()
    {
        spiral_channel();

        inlet_channel();

        outlet_channel();
    }
}


// ============================================================================
// 9. CHIP MOLD
// ============================================================================
//
// Creates a solid chip and subtracts the continuous channel.
//
// Default:
//     5 mm margin
//     4 mm chip thickness
//
// ============================================================================

module spiral_chip_mold(
    block_margin = 5.0,
    block_height = 4.0
)
{

    // ------------------------------------------------------------
    // Approximate spiral bounds
    // ------------------------------------------------------------

    spiral_min_x =
        -outer_edge_radius;

    spiral_max_x =
        outer_edge_radius;

    spiral_min_y =
        -outer_edge_radius;

    spiral_max_y =
        outer_edge_radius;


    // ------------------------------------------------------------
    // Inlet endpoint
    // ------------------------------------------------------------

    t_in = 0;

    phi_in =
        get_tangent_deg(
            t_in,
            r0,
            k
        );


    inlet_end_x =
        r0
        - l_inlet
        * cos(phi_in);

    inlet_end_y =
        0
        - l_inlet
        * sin(phi_in);


    // ------------------------------------------------------------
    // Outlet endpoint
    // ------------------------------------------------------------

    t_out =
        turns * 2 * PI;


    r_out =
        r0 + k * t_out;


    x_out =
        r_out
        * cos(t_out * 180 / PI);

    y_out =
        r_out
        * sin(t_out * 180 / PI);


    phi_out =
        get_tangent_deg(
            t_out,
            r_out,
            k
        );


    outlet_end_x =
        x_out
        + l_outlet
        * cos(phi_out);

    outlet_end_y =
        y_out
        + l_outlet
        * sin(phi_out);


    // ------------------------------------------------------------
    // Overall chip bounds
    // ------------------------------------------------------------

    min_x =
        min(
            spiral_min_x,
            inlet_end_x
        )
        - w / 2
        - block_margin;


    max_x =
        max(
            spiral_max_x,
            outlet_end_x
        )
        + w / 2
        + block_margin;


    min_y =
        min(
            spiral_min_y,
            inlet_end_y
        )
        - w / 2
        - block_margin;


    max_y =
        max(
            spiral_max_y,
            outlet_end_y
        )
        + w / 2
        + block_margin;


    block_x =
        max_x - min_x;

    block_y =
        max_y - min_y;


    block_center_x =
        (min_x + max_x) / 2;

    block_center_y =
        (min_y + max_y) / 2;


    // ------------------------------------------------------------
    // Create chip and subtract channel
    // ------------------------------------------------------------

    difference()
    {

        translate([
            block_center_x,
            block_center_y,
            block_height / 2
        ])
            cube([
                block_x,
                block_y,
                block_height
            ], center = true);


        spiral_fluid_domain();
    }
}


// ============================================================================
// 10. RENDER MODE
// ============================================================================
//
// OPTION A — show positive channel volume:
//
//     spiral_fluid_domain();
//
// OPTION B — show solid chip with engraved channel:
//
//     spiral_chip_mold();
//
// ============================================================================


// POSITIVE CHANNEL VIEW
spiral_fluid_domain();


// SOLID CHIP VIEW
// Comment out the line above and uncomment this:
//
// spiral_chip_mold();


// ============================================================================
// END
// ============================================================================