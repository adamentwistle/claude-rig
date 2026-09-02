// CRT look: scanlines, chromatic aberration, vignette, optional screen curvature.
// Set any constant to 0.0 to switch that part off.
const float SCANLINE_STRENGTH = 0.22; // darkness of the lines (0.1 faint .. 0.3 heavy)
const float SCANLINE_PERIOD = 3.0;    // pixels per line; 3 on a retina display, 2 on 1x
const float ABERRATION = 0.0;         // pixels of red/blue fringe at the edges of glyphs
const float VIGNETTE = 0.30;          // darkening toward the corners
const float CURVATURE = 0.0;          // barrel distortion; try 0.03

vec2 curve(vec2 uv) {
    uv = uv * 2.0 - 1.0;
    vec2 off = abs(uv.yx) * CURVATURE;
    uv = uv + uv * off * off;
    return uv * 0.5 + 0.5;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    if (CURVATURE > 0.0) {
        uv = curve(uv);
        if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
            fragColor = vec4(0.0, 0.0, 0.0, 1.0);
            return;
        }
    }
    vec2 ab = vec2(ABERRATION / iResolution.x, 0.0);
    float r = texture(iChannel0, uv + ab).r;
    float g = texture(iChannel0, uv).g;
    float b = texture(iChannel0, uv - ab).b;
    vec3 col = vec3(r, g, b);

    float scan = 1.0 - SCANLINE_STRENGTH * (0.5 + 0.5 * sin(fragCoord.y * 6.28318530 / SCANLINE_PERIOD));
    col *= scan;

    vec2 v = uv * 2.0 - 1.0;
    col *= 1.0 - VIGNETTE * dot(v, v) * 0.5;

    fragColor = vec4(col, 1.0);
}
