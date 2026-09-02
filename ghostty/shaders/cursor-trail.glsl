// Cursor trail: a soft streak from where the cursor was to where it is, fading out.
// TRAIL_COLOR is rewritten by ~/.claude-work/bin/ccs-theme to match the active theme.
const vec3 TRAIL_COLOR = vec3(0.463, 0.918, 0.416); // #76ea6a
const float DURATION = 0.22;  // seconds for the tail to catch up and fade
const float GLOW = 0.55;      // soft glow strength around the streak

float sdSegment(vec2 p, vec2 a, vec2 b) {
    vec2 pa = p - a;
    vec2 ba = b - a;
    float h = clamp(dot(pa, ba) / max(dot(ba, ba), 1e-4), 0.0, 1.0);
    return length(pa - ba * h);
}

float easeOut(float t) {
    return 1.0 - pow(1.0 - t, 3.0);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec4 base = texture(iChannel0, uv);
    fragColor = base;

    // cursor rects are (x, y, w, h) in pixels, y up, y = top edge
    vec2 cur = vec2(iCurrentCursor.x + iCurrentCursor.z * 0.5, iCurrentCursor.y - iCurrentCursor.w * 0.5);
    vec2 prev = vec2(iPreviousCursor.x + iPreviousCursor.z * 0.5, iPreviousCursor.y - iPreviousCursor.w * 0.5);
    float t = clamp((iTime - iTimeCursorChange) / DURATION, 0.0, 1.0);
    if (t >= 1.0 || distance(cur, prev) < 1.0) {
        return;
    }

    float e = easeOut(t);
    vec2 tail = mix(prev, cur, e);
    float halfH = iCurrentCursor.w * 0.5 * (1.0 - 0.4 * e);
    float d = sdSegment(fragCoord, tail, cur) - halfH * 0.9;
    float fade = 1.0 - e;

    float core = (1.0 - smoothstep(-1.0, 1.0, d)) * fade;
    float glow = exp(-max(d, 0.0) / (halfH * 1.5)) * GLOW * fade;

    // leave the live cursor cell alone so the glyph under it stays readable
    vec2 dd = abs(fragCoord - cur) - vec2(iCurrentCursor.z, iCurrentCursor.w) * 0.5;
    float inCursor = step(max(dd.x, dd.y), 0.0);
    float a = clamp(core * 0.85 + glow, 0.0, 1.0) * (1.0 - inCursor);

    fragColor = vec4(mix(base.rgb, TRAIL_COLOR, a), base.a);
}
