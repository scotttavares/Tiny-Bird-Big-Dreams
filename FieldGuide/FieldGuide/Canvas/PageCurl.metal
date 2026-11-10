#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

static bool onSheet(float2 p, float2 size) {
    return p.x >= 0 && p.y >= 0 && p.x <= size.x && p.y <= size.y;
}

/// The back of the sheet: the paper colour with the sketch showing faintly through, lit by `light`.
static half4 backSide(half4 front, half4 paper, half light) {
    return half4(mix(front.rgb, paper.rgb, half(0.82)) * light, 1);
}

/// Rolls a sheet of paper round a cylinder, like a page being turned.
///
/// `origin` is a point on the line where the sheet leaves the table, `normal` points across that
/// line toward the lifted side, and `radius` is the radius of the roll. Paper past the roll lies
/// flat on top, back side up. Uncovered pixels are transparent (the page underneath shows),
/// darkened by the turning sheet's shadow.
[[ stitchable ]] half4 pageCurl(float2 position, SwiftUI::Layer layer, float2 size, float2 origin, float2 normal,
                                float radius, half4 paper) {
    const float pi = 3.14159265;
    float r = max(radius, 0.5);
    float s = dot(position - origin, normal);

    if (s < 0) {
        // Paper that has rolled right over lies here, on top.
        float u = pi * r - s;
        float2 q = position + normal * (u - s);
        if (onSheet(q, size)) {
            return backSide(layer.sample(q), paper, half(0.94));
        }
        // The flat page, a touch darker where it starts to rise into the roll.
        half4 c = layer.sample(position);
        half shade = half(1.0 - 0.12 * saturate(1.0 + s / (2.0 * r)));
        return half4(c.rgb * shade, c.a);
    }

    if (s <= r) {
        float t = asin(clamp(s / r, -1.0, 1.0));
        // The upper half of the roll: the back of the sheet, brightest at the top of the curve
        // with a thin dark rim at its edge.
        float2 top = position + normal * (r * (pi - t) - s);
        if (onSheet(top, size)) {
            float k = s / r;
            half light = half(0.9 + 0.14 * k - 0.3 * smoothstep(0.97, 1.0, k));
            return backSide(layer.sample(top), paper, light);
        }
        // The lower half of the roll: the front, turning away from the light.
        float2 bottom = position + normal * (r * t - s);
        if (onSheet(bottom, size)) {
            half4 c = layer.sample(bottom);
            half shade = half(1.0 - 0.35 * (s / r) * (s / r));
            return half4(c.rgb * shade, c.a);
        }
    }

    // The page underneath, in the shadow of the lifted sheet.
    float reach = max(s - r, 0.0);
    float strength = saturate(r / 18.0);
    half alpha = half(0.34 * strength * exp(-reach / (r * 1.2 + 14.0)));
    return half4(0, 0, 0, alpha);
}
