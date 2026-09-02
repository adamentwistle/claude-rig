// Starfield: slow drifting, twinkling stars drawn only over the terminal background colour.
// BG is rewritten by ~/.claude-work/bin/ccs-theme to match the active theme.
const vec3 BG = vec3(0.141, 0.133, 0.173); // #24222c
const float BG_TOLERANCE = 0.06; // how close a pixel must be to BG to count as empty background
const float BRIGHTNESS = 0.45;   // overall star brightness (0.3 faint .. 0.7 bright)
const float SPEED = 6.0;         // drift in pixels per second
const float TWINKLE = 0.6;       // 0 = steady, 1 = full flicker

float hash21(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

vec3 layer(vec2 px, float scale, float speed, float seed) {
    vec2 p = px / scale + vec2(iTime * speed / scale, 0.0);
    vec2 cell = floor(p);
    vec2 f = fract(p);
    float h = hash21(cell + seed);
    if (h > 0.08) {
        return vec3(0.0);
    }
    vec2 pos = vec2(hash21(cell + seed + 1.7), hash21(cell + seed + 2.9)) * 0.8 + 0.1;
    float d = length(f - pos) * scale;
    float size = 1.0 + hash21(cell + seed + 4.1) * 1.5;
    float star = smoothstep(size, 0.0, d);
    float rate = 1.0 + hash21(cell + seed + 5.3) * 3.0;
    float tw = 1.0 - TWINKLE * 0.5 * (1.0 + sin(iTime * rate + h * 100.0));
    vec3 tint = mix(vec3(1.0), vec3(0.85, 0.9, 1.0), hash21(cell + seed + 6.7));
    return tint * star * tw;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec4 base = texture(iChannel0, uv);
    fragColor = base;
    float isBg = 1.0 - smoothstep(BG_TOLERANCE * 0.5, BG_TOLERANCE, distance(base.rgb, BG));
    if (isBg <= 0.0) {
        return;
    }
    vec3 stars = layer(fragCoord, 28.0, SPEED, 0.0) * 0.6
               + layer(fragCoord, 52.0, SPEED * 1.8, 10.0) * 0.9
               + layer(fragCoord, 90.0, SPEED * 3.0, 20.0) * 1.2;
    fragColor = vec4(base.rgb + stars * BRIGHTNESS * isBg, base.a);
}
