#define EXPERIMENTAL_BUMPMAP
#define ENABLE_GOD_RAYS
#define ENABLE_FRAGMENT_WAVES
//#define CLOUDS_DISABLED

uniform sampler2D baseTexture;

uniform mat4 mWorld;

uniform vec3 dayLight;
uniform vec4 skyBgColor;
uniform float fogDistance;
uniform float fogShadingParameter;
uniform vec3 eyePosition;

// The cameraOffset is the current center of the visible world.
uniform vec3 cameraOffset;
uniform float animationTimer;
#ifdef ENABLE_DYNAMIC_SHADOWS
	// shadow texture
	uniform sampler2D ShadowMapSampler;
	// shadow uniforms
	uniform vec3 v_LightDirection;
	uniform float f_textureresolution;
	uniform mat4 m_ShadowViewProj;
	uniform float f_shadowfar;
	uniform float f_shadow_strength;
	uniform vec4 CameraPos;
	uniform float xyPerspectiveBias0;
	uniform float xyPerspectiveBias1;
	uniform float zPerspectiveBias;
	
	varying float adj_shadow_strength;
	varying float cosLight;
	varying float f_normal_length;
	varying vec3 shadow_position;
	varying float perspective_factor;
#endif


varying vec3 vNormal;
varying vec3 dNormal;
varying vec3 vPosition;
// World position in the visible world (i.e. relative to the cameraOffset.)
// This can be used for many shader effects without loss of precision.
// If the absolute position is required it can be calculated with
// cameraOffset + worldPosition (for large coordinates the limits of float
// precision must be considered).
varying vec3 worldPosition;
varying lowp vec4 varColor;
#ifdef GL_ES
varying mediump vec2 varTexCoord;
#else
centroid varying vec2 varTexCoord;
#endif
varying vec3 eyeVec;
varying float nightRatio;
varying vec3 tsEyeVec;
varying vec3 lightVec;
varying vec3 tsLightVec;

varying vec3 viewVec;
varying float leaves;
varying vec3 leavesPos;

#ifdef ENABLE_DYNAMIC_SHADOWS

vec4 perm(vec4 x)
{
	return mod(((x * 34.0) + 1.0) * x, 289.0);
}

float snoise(vec3 p)
{
	vec3 a = floor(p);
	vec3 d = p - a;
	d = d * d * (3.0 - 2.0 * d);

	vec4 b = a.xxyy + vec4(0.0, 1.0, 0.0, 1.0);
	vec4 k1 = perm(b.xyxy);
	vec4 k2 = perm(k1.xyxy + b.zzww);

	vec4 c = k2 + a.zzzz;
	vec4 k3 = perm(c);
	vec4 k4 = perm(c + 1.0);

	vec4 o1 = fract(k3 * (1.0 / 41.0));
	vec4 o2 = fract(k4 * (1.0 / 41.0));

	vec4 o3 = o2 * d.z + o1 * (1.0 - d.z);
	vec2 o4 = o3.yw * d.x + o3.xz * (1.0 - d.x);

	return o4.y * d.y + o4.x * (1.0 - d.y);
}

float fnoise(vec3 p) {
	return snoise(p) * 0.5 + snoise(p * 2.) * 0.25;
}

float wnoise(vec3 p, float off) {
	return snoise(p + vec3(off, off, 0.)) * 0.4 + snoise(2. * p + vec3(0., off, off)) * 0.2 + snoise(3. * p + vec3(0., off, off)) * 0.15 + snoise(4. *p + vec3(-off, off, 0.)) * 0.1;
}

vec4 getRelativePosition(in vec4 position)
{
	vec2 l = position.xy - CameraPos.xy;
	vec2 s = l / abs(l);
	s = (1.0 - s * CameraPos.xy);
	l /= s;
	return vec4(l, s);
}

float getPerspectiveFactor(in vec4 relativePosition)
{
	float pDistance = length(relativePosition.xy);
	float pFactor = pDistance * xyPerspectiveBias0 + xyPerspectiveBias1;
	return pFactor;
}

vec4 applyPerspectiveDistortion(in vec4 position)
{
	vec4 l = getRelativePosition(position);
	float pFactor = getPerspectiveFactor(l);
	l.xy /= pFactor;
	position.xy = l.xy * l.zw + CameraPos.xy;
	position.z *= zPerspectiveBias;
	return position;
}

// assuming near is always 1.0
float getLinearDepth()
{
	return 2.0 * f_shadowfar / (f_shadowfar + 1.0 - (2.0 * gl_FragCoord.z - 1.0) * (f_shadowfar - 1.0));
}

vec3 getLightSpacePosition()
{
	return shadow_position * 0.5 + 0.5;
}

// custom smoothstep implementation because it's not defined in glsl1.2
// https://docs.gl/sl4/smoothstep
float mtsmoothstep(in float edge0, in float edge1, in float x)
{
	float t = clamp((x - edge0) / (edge1 - edge0), 0.0, 1.0);
	return t * t * (3.0 - 2.0 * t);
}

#ifdef COLORED_SHADOWS

// c_precision of 128 fits within 7 base-10 digits
const float c_precision = 128.0;
const float c_precisionp1 = c_precision + 1.0;

float packColor(vec3 color)
{
	return floor(color.b * c_precision + 0.5)
		+ floor(color.g * c_precision + 0.5) * c_precisionp1
		+ floor(color.r * c_precision + 0.5) * c_precisionp1 * c_precisionp1;
}

vec3 unpackColor(float value)
{
	vec3 color;
	color.b = mod(value, c_precisionp1) / c_precision;
	color.g = mod(floor(value / c_precisionp1), c_precisionp1) / c_precision;
	color.r = floor(value / (c_precisionp1 * c_precisionp1)) / c_precision;
	return color;
}

vec4 getHardShadowColor(sampler2D shadowsampler, vec2 smTexCoord, float realDistance)
{
	vec4 texDepth = texture2D(shadowsampler, smTexCoord.xy).rgba;

	float visibility = step(0.0, realDistance - texDepth.r);
	vec4 result = vec4(visibility, vec3(0.0,0.0,0.0));//unpackColor(texDepth.g));
	if (visibility < 0.1) {
		visibility = step(0.0, realDistance - texDepth.b);
		result = vec4(visibility, unpackColor(texDepth.a));
	}
	return result;
}

#else

float getHardShadow(sampler2D shadowsampler, vec2 smTexCoord, float realDistance)
{
	float texDepth = texture2D(shadowsampler, smTexCoord.xy).r;
	float visibility = step(0.0, realDistance - texDepth);
	return visibility;
}

#endif


#if SHADOW_FILTER == 2
	#define PCFBOUND 2.0 // 5x5
	#define PCFSAMPLES 25
#elif SHADOW_FILTER == 1
	#define PCFBOUND 1.0 // 3x3
	#define PCFSAMPLES 9
#else
	#define PCFBOUND 0.0
	#define PCFSAMPLES 1
#endif

#ifdef COLORED_SHADOWS
float getHardShadowDepth(sampler2D shadowsampler, vec2 smTexCoord, float realDistance)
{
	vec4 texDepth = texture2D(shadowsampler, smTexCoord.xy);
	float depth = max(realDistance - texDepth.r, realDistance - texDepth.b);
	return depth;
}
#else
float getHardShadowDepth(sampler2D shadowsampler, vec2 smTexCoord, float realDistance)
{
	float texDepth = texture2D(shadowsampler, smTexCoord.xy).r;
	float depth = realDistance - texDepth;
	return depth;
}
#endif

#define BASEFILTERRADIUS 1.0

float getPenumbraRadius(sampler2D shadowsampler, vec2 smTexCoord, float realDistance)
{
	// Return fast if sharp shadows are requested
	if (PCFBOUND == 0.0 || SOFTSHADOWRADIUS <= 0.0)
		return 0.0;

	vec2 clampedpos;
	float y, x;
	float depth = getHardShadowDepth(shadowsampler, smTexCoord.xy, realDistance);
	// A factor from 0 to 1 to reduce blurring of short shadows
	float sharpness_factor = 1.0;
	// conversion factor from shadow depth to blur radius
	float depth_to_blur = f_shadowfar / SOFTSHADOWRADIUS / xyPerspectiveBias0;
	if (depth > 0.0 && f_normal_length > 0.0)
		// 5 is empirical factor that controls how fast shadow loses sharpness
		sharpness_factor = clamp(5 * depth * depth_to_blur, 0.0, 1.0);
	depth = 0.0;

	float world_to_texture = xyPerspectiveBias1 / perspective_factor / perspective_factor
			* f_textureresolution / 2.0 / f_shadowfar;
	float world_radius = 0.2; // shadow blur radius in world float coordinates, e.g. 0.2 = 0.02 of one node

	return max(BASEFILTERRADIUS * f_textureresolution / 4096.0,  sharpness_factor * world_radius * world_to_texture * SOFTSHADOWRADIUS);
}

#ifdef POISSON_FILTER
const vec2[64] poissonDisk = vec2[64](
	vec2(0.170019, -0.040254),
	vec2(-0.299417, 0.791925),
	vec2(0.645680, 0.493210),
	vec2(-0.651784, 0.717887),
	vec2(0.421003, 0.027070),
	vec2(-0.817194, -0.271096),
	vec2(-0.705374, -0.668203),
	vec2(0.977050, -0.108615),
	vec2(0.063326, 0.142369),
	vec2(0.203528, 0.214331),
	vec2(-0.667531, 0.326090),
	vec2(-0.098422, -0.295755),
	vec2(-0.885922, 0.215369),
	vec2(0.566637, 0.605213),
	vec2(0.039766, -0.396100),
	vec2(0.751946, 0.453352),
	vec2(0.078707, -0.715323),
	vec2(-0.075838, -0.529344),
	vec2(0.724479, -0.580798),
	vec2(0.222999, -0.215125),
	vec2(-0.467574, -0.405438),
	vec2(-0.248268, -0.814753),
	vec2(0.354411, -0.887570),
	vec2(0.175817, 0.382366),
	vec2(0.487472, -0.063082),
	vec2(0.355476, 0.025357),
	vec2(-0.084078, 0.898312),
	vec2(0.488876, -0.783441),
	vec2(0.470016, 0.217933),
	vec2(-0.696890, -0.549791),
	vec2(-0.149693, 0.605762),
	vec2(0.034211, 0.979980),
	vec2(0.503098, -0.308878),
	vec2(-0.016205, -0.872921),
	vec2(0.385784, -0.393902),
	vec2(-0.146886, -0.859249),
	vec2(0.643361, 0.164098),
	vec2(0.634388, -0.049471),
	vec2(-0.688894, 0.007843),
	vec2(0.464034, -0.188818),
	vec2(-0.440840, 0.137486),
	vec2(0.364483, 0.511704),
	vec2(0.034028, 0.325968),
	vec2(0.099094, -0.308023),
	vec2(0.693960, -0.366253),
	vec2(0.678884, -0.204688),
	vec2(0.001801, 0.780328),
	vec2(0.145177, -0.898984),
	vec2(0.062655, -0.611866),
	vec2(0.315226, -0.604297),
	vec2(-0.780145, 0.486251),
	vec2(-0.371868, 0.882138),
	vec2(0.200476, 0.494430),
	vec2(-0.494552, -0.711051),
	vec2(0.612476, 0.705252),
	vec2(-0.578845, -0.768792),
	vec2(-0.772454, -0.090976),
	vec2(0.504440, 0.372295),
	vec2(0.155736, 0.065157),
	vec2(0.391522, 0.849605),
	vec2(-0.620106, -0.328104),
	vec2(0.789239, -0.419965),
	vec2(-0.545396, 0.538133),
	vec2(-0.178564, -0.596057)
);

#ifdef COLORED_SHADOWS

vec4 getShadowColor(sampler2D shadowsampler, vec2 smTexCoord, float realDistance)
{
	float radius = getPenumbraRadius(shadowsampler, smTexCoord, realDistance);
	if (radius < 0.1) {
		// we are in the middle of even brightness, no need for filtering
		return getHardShadowColor(shadowsampler, smTexCoord.xy, realDistance);
	}

	vec2 clampedpos;
	vec4 visibility = vec4(0.0);
	float scale_factor = radius / f_textureresolution;

	int samples = (1 + 1 * int(SOFTSHADOWRADIUS > 1.0)) * PCFSAMPLES; // scale max samples for the soft shadows
	samples = int(clamp(pow(4.0 * radius + 1.0, 2.0), 1.0, float(samples)));
	int init_offset = int(floor(mod(((smTexCoord.x * 34.0) + 1.0) * smTexCoord.y, 64.0-samples)));
	int end_offset = int(samples) + init_offset;

	for (int x = init_offset; x < end_offset; x++) {
		clampedpos = poissonDisk[x] * scale_factor + smTexCoord.xy;
		visibility += getHardShadowColor(shadowsampler, clampedpos.xy, realDistance);
	}

	return visibility / samples;
}

#else

float getShadow(sampler2D shadowsampler, vec2 smTexCoord, float realDistance)
{
	float radius = getPenumbraRadius(shadowsampler, smTexCoord, realDistance);
	if (radius < 0.1) {
		// we are in the middle of even brightness, no need for filtering
		return getHardShadow(shadowsampler, smTexCoord.xy, realDistance);
	}

	vec2 clampedpos;
	float visibility = 0.0;
	float scale_factor = radius / f_textureresolution;

	int samples = (1 + 1 * int(SOFTSHADOWRADIUS > 1.0)) * PCFSAMPLES; // scale max samples for the soft shadows
	samples = int(clamp(pow(4.0 * radius + 1.0, 2.0), 1.0, float(samples)));
	int init_offset = int(floor(mod(((smTexCoord.x * 34.0) + 1.0) * smTexCoord.y, 64.0-samples)));
	int end_offset = int(samples) + init_offset;

	for (int x = init_offset; x < end_offset; x++) {
		clampedpos = poissonDisk[x] * scale_factor + smTexCoord.xy;
		visibility += getHardShadow(shadowsampler, clampedpos.xy, realDistance);
	}

	return visibility / samples;
}

#endif

#else
/* poisson filter disabled */

#ifdef COLORED_SHADOWS

vec4 getShadowColor(sampler2D shadowsampler, vec2 smTexCoord, float realDistance)
{
	float radius = getPenumbraRadius(shadowsampler, smTexCoord, realDistance);
	if (radius < 0.1) {
		// we are in the middle of even brightness, no need for filtering
		return getHardShadowColor(shadowsampler, smTexCoord.xy, realDistance);
	}

	vec2 clampedpos;
	vec4 visibility = vec4(0.0);
	float x, y;
	float bound = (1 + 0.5 * int(SOFTSHADOWRADIUS > 1.0)) * PCFBOUND; // scale max bound for soft shadows
	bound = clamp(0.5 * (4.0 * radius - 1.0), 0.5, bound);
	float scale_factor = radius / bound / f_textureresolution;
	float n = 0.0;

	// basic PCF filter
	for (y = -bound; y <= bound; y += 1.0)
	for (x = -bound; x <= bound; x += 1.0) {
		clampedpos = vec2(x,y) * scale_factor + smTexCoord.xy;
		visibility += getHardShadowColor(shadowsampler, clampedpos.xy, realDistance);
		n += 1.0;
	}

	return visibility / max(n, 1.0);
}

#else
float getShadow(sampler2D shadowsampler, vec2 smTexCoord, float realDistance)
{
	float radius = getPenumbraRadius(shadowsampler, smTexCoord, realDistance);
	if (radius < 0.1) {
		// we are in the middle of even brightness, no need for filtering
		return getHardShadow(shadowsampler, smTexCoord.xy, realDistance);
	}

	vec2 clampedpos;
	float visibility = 0.0;
	float x, y;
	float bound = (1 + 0.5 * int(SOFTSHADOWRADIUS > 1.0)) * PCFBOUND; // scale max bound for soft shadows
	bound = clamp(0.5 * (4.0 * radius - 1.0), 0.5, bound);
	float scale_factor = radius / bound / f_textureresolution;
	float n = 0.0;

	// basic PCF filter
	for (y = -bound; y <= bound; y += 1.0)
	for (x = -bound; x <= bound; x += 1.0) {
		clampedpos = vec2(x,y) * scale_factor + smTexCoord.xy;
		visibility += getHardShadow(shadowsampler, clampedpos.xy, realDistance);
		n += 1.0;
	}

	return visibility / max(n, 1.0);
}

#endif

#endif
#endif

#ifdef COLORED_SHADOWS
vec3 getGodRay(vec3 position) {
	vec3 sm_coords = applyPerspectiveDistortion(m_ShadowViewProj * vec4(position, 1.)).xyz * 0.5 + 0.5;
	vec4 c = 1. - getHardShadowColor(ShadowMapSampler, sm_coords.xy, sm_coords.z);
	return c.gba * c.r;
}
#else
float getGodRay(vec3 position) {
	vec3 sm_coords = applyPerspectiveDistortion(m_ShadowViewProj * vec4(position, 1.)).xyz * 0.5 + 0.5;
	return 1. - getHardShadow(ShadowMapSampler, sm_coords.xy, sm_coords.z);
}
#endif

void main(void)
{
	vec3 color;
	vec2 uv = varTexCoord.st;

	vec4 base = texture2D(baseTexture, uv).rgba;
	// If alpha is zero, we can just discard the pixel. This fixes transparency
	// on GPUs like GC7000L, where GL_ALPHA_TEST is not implemented in mesa,
	// and also on GLES 2, where GL_ALPHA_TEST is missing entirely.
#ifdef USE_DISCARD
	if (base.a == 0.0)
		discard;
#endif
#ifdef USE_DISCARD_REF
	if (base.a < 0.5)
		discard;
#endif

	color = base.rgb;
	vec4 col = vec4(color.rgb * varColor.rgb, 1.0);

vec3 cNormal = vNormal;

#if (defined(EXPERIMENTAL_BUMPMAP) && MATERIAL_TYPE != TILE_MATERIAL_WAVING_LIQUID_TRANSPARENT)
	float dx = 0.02;
	float fx0y0 = fnoise(vec3(uv * 40., 0.)) + texture2D(baseTexture, uv).r * 0.5;
	float fx1y0 = fnoise(vec3(uv * 40. + vec2(dx, 0.), 0.)) + texture2D(baseTexture, uv + vec2(dx, 0.)).r * 0.5;
	float fx0y1 = fnoise(vec3(uv * 40. + vec2(0., dx), 0.)) + texture2D(baseTexture, uv + vec2(0., dx)).r * 0.5;
	vec3 orth1 = normalize(cross(vNormal, mix(vec3(0., -1., 0.), vec3(0., 0., -1.), step(0.9, abs(vNormal.y)))));
	vec3 orth2 = normalize(cross(vNormal, orth1));
	cNormal = normalize(vNormal + (orth1 * (fx1y0 - fx0y0) / dx + orth2 * (fx0y1 - fx0y0) / dx) * 0.25);
	float adj_cosLight = max(1e-5, dot(cNormal, -v_LightDirection));
#else 
	float adj_cosLight = cosLight;
#endif

#ifdef ENABLE_DYNAMIC_SHADOWS
	if (f_shadow_strength > 0.0) {
		float shadow_int = 0.0;
		vec3 shadow_color = vec3(0.0, 0.0, 0.0);
		vec3 posLightSpace = getLightSpacePosition();

		float distance_rate = (1.0 - pow(clamp(2.0 * length(posLightSpace.xy - 0.5),0.0,1.0), 10.0));
		if (max(abs(posLightSpace.x - 0.5), abs(posLightSpace.y - 0.5)) > 0.5)
			distance_rate = 0.0;

#ifdef CLOUDS_DISABLED
		float f_adj_shadow_strength = 0.6 * (mtsmoothstep(0.24, 0.3, dayLight.r) + mtsmoothstep(0.155, 0.105, dayLight.r));
#else
		float f_adj_shadow_strength = max(adj_shadow_strength - mtsmoothstep(0.9, 1.1, posLightSpace.z),0.0);
#endif

		if (distance_rate > 1e-7) {

#ifdef COLORED_SHADOWS
			vec4 visibility;
			if (adj_cosLight > 0.0 || f_normal_length < 1e-3 || leaves > 0.1)
				visibility = getShadowColor(ShadowMapSampler, posLightSpace.xy, posLightSpace.z);
			else
				visibility = vec4(1.0, 0.0, 0.0, 0.0);
			shadow_int = visibility.r;
			shadow_color = visibility.gba;
#else
			if (adj_cosLight > 0.0 || f_normal_length < 1e-3 || leaves > 0.1)
				shadow_int = getShadow(ShadowMapSampler, posLightSpace.xy, posLightSpace.z);
			else
				shadow_int = 1.0;
#endif
			shadow_int *= distance_rate;
			shadow_int = clamp(shadow_int, 0.0, 1.0);

		}

		// turns out that nightRatio falls off much faster than
		// actual brightness of artificial light in relation to natual light.
		// Power ratio was measured on torches in MTG (brightness = 14).
		float adjusted_night_ratio = pow(max(0.0, nightRatio), 0.6);

#if (MATERIAL_TYPE == TILE_MATERIAL_WAVING_LEAVES && ENABLE_WAVING_LEAVES)
		vec3 leafPos = mod(leavesPos, vec3(1.)) * 2. - 1.;
		vec3 smooth_normal = normalize(vNormal + leafPos - vNormal * dot(leafPos, vNormal));
		float light_factor = max(dot(smooth_normal, v_LightDirection) * 0.8 + 0.2, 0.);

		// Apply self-shadowing when light falls at a narrow angle to the surface
		// Cosine of the cut-off angle.
		const float self_shadow_cutoff_cosine = 0.035;
		if (f_normal_length != 0 && cosLight < self_shadow_cutoff_cosine) {
			shadow_int = max(shadow_int, 1 - clamp(adj_cosLight, 0.0, self_shadow_cutoff_cosine)/self_shadow_cutoff_cosine) * light_factor + shadow_int * (1. - light_factor);
			shadow_color = mix(vec3(0.0), shadow_color, min(adj_cosLight, self_shadow_cutoff_cosine)/self_shadow_cutoff_cosine) * light_factor + shadow_color * (1. - light_factor);
		}
#else
		// Apply self-shadowing when light falls at a narrow angle to the surface
		// Cosine of the cut-off angle.
		const float self_shadow_cutoff_cosine = 0.035;
		if (f_normal_length != 0 && adj_cosLight < self_shadow_cutoff_cosine) {
			shadow_int = max(shadow_int, 1 - clamp(adj_cosLight, 0.0, self_shadow_cutoff_cosine)/self_shadow_cutoff_cosine);
			shadow_color = mix(vec3(0.0), shadow_color, min(adj_cosLight, self_shadow_cutoff_cosine)/self_shadow_cutoff_cosine);
		}
#endif

		float shadow_uncorrected = shadow_int;
		shadow_int *= f_adj_shadow_strength;

		float tint_factor = min(abs(v_LightDirection.y) * 3., 1.);
		float tint_strength = clamp((dayLight.r - 0.1) * 5., 0., 1.) * (1. - min(shadow_uncorrected, 1.) * 0.125) * min(f_adj_shadow_strength * 2., 1.);
		vec3 sun_tint = vec3(1., pow(tint_factor, 0.5), pow(tint_factor, 2.)) * (tint_strength * 0.75) + vec3(tint_factor * 0.5 + 0.5) * (1. - tint_strength * 0.75);
		vec3 tinted_dayLight = dayLight * sun_tint;

		// calculate fragment color from components:
		col.rgb =
				adjusted_night_ratio * col.rgb + // artificial light
				(1.0 - adjusted_night_ratio) * sun_tint * ( // natural light
						col.rgb * (1.0 - shadow_int * (1.0 - shadow_color) * vec3(1., 0.85, 0.6)) +  // filtered texture color
						dayLight * shadow_color * shadow_int);                 // reflected filtered sunlight/moonlight

#if (MATERIAL_TYPE == TILE_MATERIAL_WAVING_LIQUID_TRANSPARENT)
#ifdef ENABLE_FRAGMENT_WAVES
		vec3 wavePos = worldPosition * vec3(2., 0., 2.);
		float off = animationTimer * WATER_WAVE_SPEED * 10.0;
		wavePos.x /= WATER_WAVE_LENGTH * 3.0;
		wavePos.z /= WATER_WAVE_LENGTH * 4.0;
		float fxy = wnoise(wavePos, off);
		float dydx = (wnoise(wavePos + vec3(0.1, 0., 0.), off) - fxy) / 0.1;
		float dydz = (wnoise(wavePos + vec3(0., 0., 0.1), off) - fxy) / 0.1;
		vec3 fNormal = normalize(normalize(dNormal) + vec3(-dydx, 0., -dydz) * WATER_WAVE_HEIGHT * 0.25 * abs(dNormal.y));
#else
		vec3 fNormal = normalize(dNormal);
#endif
		float dp = dot(fNormal, viewVec);
		dp =  clamp(pow(1. - dp * dp, 8.), 0., 1.);
		col.rgb *= 0.5;
		vec3 reflection_color = mix(vec3(max(skyBgColor.r, max(skyBgColor.g, skyBgColor.b))), skyBgColor.rgb, f_adj_shadow_strength);
		col.rgb += reflection_color * pow((1. - adjusted_night_ratio) * dp, 2.) * 0.5;
		vec3 reflect_ray = -normalize(v_LightDirection - fNormal * dot(v_LightDirection, fNormal) * 2.);
		col.rgb += tinted_dayLight * 16. * dp * mtsmoothstep(0.85, 0.9, pow(clamp(dot(reflect_ray, viewVec), 0., 1.), 32.)) * max(1. - shadow_uncorrected, 0.) * f_adj_shadow_strength;
#else
		vec3 leaf_reflect_ray = -normalize(v_LightDirection - cNormal * dot(v_LightDirection, cNormal) * 2.);
		col.rgb += 
			tinted_dayLight * f_adj_shadow_strength * 
			pow(max(dot(leaf_reflect_ray, viewVec), 0.), 4.) * pow(1. - abs(dot(viewVec, vNormal)), 8.) * 
			(1. - shadow_uncorrected) * (1. - base.r) * 4. * (leaves * 0.5 + 0.5) * length(vNormal);
#endif

		col.rgb += base.rgb * normalize(base.rgb) * tinted_dayLight * f_adj_shadow_strength * 5. * leaves * pow(max(-dot(v_LightDirection, viewVec), 0.), 16.) * max(1. - shadow_uncorrected, 0.);
		
		float sun_scatter = pow(max(-dot(v_LightDirection, viewVec), 0.), 4.);

#ifdef ENABLE_GOD_RAYS
		float bias = step(mod(gl_FragCoord.y * 0.5, 2), 0.8) * 0.125 + step(mod((gl_FragCoord.y + gl_FragCoord.x) * 0.5, 2), 0.8) * 0.0625 + step(mod(gl_FragCoord.y, 2), 0.8) * 0.5 + step(mod(gl_FragCoord.y + gl_FragCoord.x, 2), 0.8) * 0.25;
#ifdef COLORED_SHADOWS
		vec3 ray_intensity = vec3(0.);
		float ray_length = max(length(eyeVec) - 5., 0.);
		vec3 ray_origin = eyePosition - (vec4(cameraOffset, 1.) * mWorld).xyz + viewVec * 5.;
		for (int i = 0; i < 20; i++) {
			float f = (float(i) + bias) / 20.;
			float dist = ray_length * f * f;
			vec3 ray_position = ray_origin + viewVec * dist;
			ray_intensity += getGodRay(ray_position) * 0.0002 * float(2 * i + 1) * exp(-dist * 0.1) * ray_length;
		}
		ray_intensity *= sun_scatter;

		col.rgb += tinted_dayLight * ray_intensity * vec3(1., 0.7, 0.4) * f_adj_shadow_strength * adjusted_night_ratio;
#else
		float ray_intensity = 0.;
		float ray_length = max(length(eyeVec) - 5., 0.);
		vec3 ray_origin = eyePosition - (vec4(cameraOffset, 1.) * mWorld).xyz + viewVec * 5.;
		for (int i = 0; i < 20; i++) {
			float f = (float(i) + bias) / 20.;
			float dist = ray_length * f * f;
			vec3 ray_position = ray_origin + viewVec * dist;
			ray_intensity += getGodRay(ray_position) * 0.0002 * float(2 * i + 1) * exp(-dist * 0.1) * ray_length;
		}
		ray_intensity *= sun_scatter;

		col.rgb += tinted_dayLight * ray_intensity * vec3(1., 0.7, 0.4) * f_adj_shadow_strength;
#endif
#endif
		//col.rgb += max(mix(vec3(skyBgColor.b), skyBgColor.rgb, 2.), vec3(0.)) * (1. - sun_scatter) * (1. - exp(-length(eyeVec) * 0.375 / fogDistance));
	}
#endif

	// Due to a bug in some (older ?) graphics stacks (possibly in the glsl compiler ?),
	// the fog will only be rendered correctly if the last operation before the
	// clamp() is an addition. Else, the clamp() seems to be ignored.
	// E.g. the following won't work:
	//      float clarity = clamp(fogShadingParameter
	//		* (fogDistance - length(eyeVec)) / fogDistance), 0.0, 1.0);
	// As additions usually come for free following a multiplication, the new formula
	// should be more efficient as well.
	// Note: clarity = (1 - fogginess)
	float clarity = clamp(fogShadingParameter
		- fogShadingParameter * length(eyeVec) / fogDistance, 0.0, 1.0);
	float skyBgMax = max(max(skyBgColor.r, skyBgColor.g), skyBgColor.b);
	if (skyBgMax < 0.0000001) skyBgMax = 1.;
	col = mix(skyBgColor * pow(skyBgColor / skyBgMax, vec4(2. * clarity)), col, clarity);
	col = vec4(col.rgb, base.a);

	gl_FragData[0] = col;
}
