# GDScript SDF

A pure GDScript 2D Signed Distance Field (SDF) sprite generator and editor composition plugin for Godot 4.

Create procedural sprites, shapes, and icons directly inside the Godot editor using standard mathematical functions and boolean operations.

---

## Technical Overview & Logic

This tool generates images proceduraly by evaluating Signed Distance Fields (SDFs) on the CPU:

1. **Hierarchy Gathering**: An `SdfSpriteGenerator` node scans its children for nodes inheriting from `SdfShape`.
2. **Coordinate Transformation**: For each pixel on the canvas, the coordinate is transformed into the local coordinate space of each shape node. This takes into account the shape's position, rotation, and scale relative to the generator:
   $$\mathbf{p}_{\text{local}} = (\mathbf{T}_{\text{shape}})^{-1} \times \mathbf{T}_{\text{generator}} \times \mathbf{p}_{\text{pixel}}$$
3. **SDF Evaluation**: The shape's respective SDF function (e.g., Circle, Box, Capsule, Triangle) is evaluated at that point.
4. **Constructive Solid Geometry (CSG)**: Distances are combined sequentially based on the shape's boolean operation:
   - **Union**: $\min(d_1, d_2)$
   - **Subtraction**: $\max(d_1, -d_2)$
   - **Intersection**: $\max(d_1, d_2)$
5. **Smooth Blending**: When `smooth_k` is greater than `0.0`, the tool uses polynomial smooth minimum/maximum functions (smin) to create organic transitions and blends between shapes.
6. **Symmetry**: Optional horizontal and/or vertical symmetry mirror coordinates before shape evaluation.
7. **Post-Processing Layers**: Outlines and glow values are calculated based on the final distance field values, blending with custom colors and antialiased step functions.

---

## ⚠️ Performance & Recommendations

> [!IMPORTANT]
> Because pixel evaluation and coordinate transformations are calculated sequentially **on the CPU in GDScript**, this tool is **not intended for real-time runtime generation** (such as per-frame evaluations).
>
> Composing complex shapes at runtime can cause frame drops, especially at larger resolutions, since the algorithm's complexity is:
> $$\mathcal{O}(W \times H \times N)$$
> where $W \times H$ is the sprite resolution and $N$ is the number of shape nodes.

### Recommended Workflow:
1. **Design in the Editor**: Compose your complex shapes and characters in the editor using the shape nodes.
2. **Bake to PNG**: Use the Inspector button **"Save PNG & Export"** on the `SdfSpriteGenerator` node to write the result as a PNG texture.
3. **Use Static Textures**: The tool automatically re-imports the PNG and can automatically generate a sibling `Sprite2D` node with the texture assigned. Use these baked assets in your active game scene.

---

## Installation

1. Copy the `addons/gdscript_sdf` directory into your Godot project's `addons/` directory.
2. Open your Godot project.
3. Navigate to **Project -> Project Settings -> Plugins** and check the **Enabled** box next to **GDScript SDF**.

---

## Features & Supported Shapes

- **SdfCircle**: Configurable radius.
- **SdfBox**: Configurable width/height and corner rounding.
- **SdfCapsule**: Configurable height and radius.
- **SdfLine**: Configurable length and thickness.
- **SdfRing**: Configurable radius and line thickness.
- **SdfTriangle**: Configurable 3-point vertices.
- **CSG Operations**: Union, Subtraction, and Intersection (with optional smooth blending).
- **Styling**: Customizable background color, antialiasing toggles, outline thickness/color, and glow size/color.

---

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
