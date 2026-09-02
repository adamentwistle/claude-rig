// Bloom: a faint glow on bright pixels (brand green/purple, the cursor, status line chips).
const float THRESHOLD = 0.45; // only pixels brighter than this bloom
const float INTENSITY = 0.65; // 0.2 subtle .. 0.4 tasteful .. 0.8 loud
const float SPREAD = 2.4;     // pixels between blur taps

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec4 base = texture(iChannel0, uv);
    vec3 glow = vec3(0.0);
    float total = 0.0;
    for (int x = -3; x <= 3; x++) {
        for (int y = -3; y <= 3; y++) {
            vec2 off = vec2(float(x), float(y)) * SPREAD / iResolution.xy;
            vec3 c = texture(iChannel0, uv + off).rgb;
            float lum = dot(c, vec3(0.299, 0.587, 0.114));
            float w = exp(-float(x * x + y * y) / 5.0);
            glow += c * smoothstep(THRESHOLD, 1.0, lum) * w;
            total += w;
        }
    }
    glow /= total;
    fragColor = vec4(min(base.rgb + glow * INTENSITY, vec3(1.0)), base.a);
}
