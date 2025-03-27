#version 320 es

precision highp float;
in vec2 v_texcoord;
uniform sampler2D tex;

out vec4 outColor;

/* Parameters describing the display geometry */
const float CURVATURE_RADIUS = 1.0; // in meters
const float SCREEN_DIAG_IN = 49.0; // in inches
const float ASPECT_RATIO = 32.0/9.0;

/* Parameters defining the view point */
// NOTE: All values in meters
const float EYE_DISTANCE_FROM_MONITOR = 0.6; // measured at the furthest point of the curved display (typically the center)
const float EYE_OFFSET_VERTICAL = 0.05; // offset from the center of the screen in the vertical direction
const float EYE_OFFSET_HORIZONTAL = 0.0; // offset from the center of the screen in the horizontal direction

/* General parameters */
// This ensures that the main content is still visible after the projection and avoids blurriness in the center of the image.
// The downside is that not the entire screen is covered with the resulting projection. 
// Note: both options should be equally correct and this boils down to personal preference and the content.
const bool INSET_PROJECTION = true;
// Use manual implementation of bi-cubic filtering for better image quality
const bool BICUBIC_FILTERING = true;
// This likely doesn't need to be changed (depends on the how texture coordinates are passed to this shader)
// Adapt texture coordinates as code assumes texture origin in top left corner
const bool FLIP_UV_FROM_OGL = true;

/*
Implementation of cubic (Catmull-Rom) texture filtering based on the vulkan specification:
https://www.khronos.org/registry/vulkan/specs/1.3-extensions/html/vkspec.html#textures-texel-filtering
*/
vec4 textureBicubic(sampler2D tex, vec2 texCoords) {
	vec2 size = vec2(textureSize(tex, 0));
	vec2 unnormalized = texCoords * size;
	vec2 w = fract(unnormalized - 0.5);
	vec2 w2 = w * w;
	vec2 w3 = w2 * w;
	mat4 f = mat4(
		0, -1, 2, -1,
		2, 0, -5, 3,
		0, 1, 4, -3,
		0, 0, -1, 1
	);
	vec4 catmulRomWeightsI = 0.5 * vec4(1, w.x, w2.x, w3.x) * f;
	vec4 catmulRomWeightsJ = 0.5 * vec4(1, w.y, w2.y, w3.y) * f;

	vec4 interpolated = vec4(0);
	for(int i = 0; i < 4; i++) {
		for(int j = 0; j < 4; j++) {
			ivec2 intCoords = ivec2(floor(unnormalized - 3.0/2.0))
				+ ivec2(i, j);
			vec4 texelData = texelFetch(tex, intCoords, 0);
			interpolated += catmulRomWeightsI[i]
				* catmulRomWeightsJ[j] * texelData;
		}
	}

	return interpolated;
}

float rayPlaneDistance(vec3 ray_direction, vec3 ray_origin, vec3 plane_normal, float plane_distance) {
    // distance from origin to intersection with plane
    return -(dot(ray_origin, plane_normal) + plane_distance) / dot(ray_direction, plane_normal);
}

vec3 rayPlaneInersection(vec3 ray_direction, vec3 ray_origin, vec3 plane_normal, float plane_distance) {
    // distance from origin to intersection with plane
    float t = rayPlaneDistance(ray_direction, ray_origin, plane_normal, plane_distance);
    // point of intersection with plane
    return ray_origin + t * ray_direction;
}

vec2 undistorTextureCoordinates(vec2 texCoord)
{
    const float screen_diag = SCREEN_DIAG_IN * 2.54 / 100.0; // convert in to m
    const float invSqrAspect = 1.0 / sqrt(1.0 + ASPECT_RATIO * ASPECT_RATIO);

    const float screen_height = screen_diag * invSqrAspect;
    const float screen_width = screen_diag * ASPECT_RATIO * invSqrAspect;

    const float half_angle_rad = (screen_width / CURVATURE_RADIUS) / 2.0; // screen_width is the arc length
    const float half_secant_length = sin(half_angle_rad) * CURVATURE_RADIUS;

    const vec3 gazePosition = vec3(EYE_OFFSET_HORIZONTAL, EYE_OFFSET_VERTICAL, -CURVATURE_RADIUS + EYE_DISTANCE_FROM_MONITOR);

    float distance_center_to_secant = cos(half_angle_rad) * CURVATURE_RADIUS;
    float distance_observer_to_secant = max(distance_center_to_secant + gazePosition.z, 0.01); // limit to 1 cm in front of secant

    // calculate true vertical frustum bounds
    float distance_center_to_tangent = CURVATURE_RADIUS;
    float distance_observer_to_tangent = distance_center_to_tangent + gazePosition.z; // limit to 1 cm in front of secant

    // top limit
    vec3 top_cylinder = vec3(0, screen_height / 2.0, -distance_center_to_tangent);
    vec3 observer_to_top = top_cylinder - vec3(gazePosition);
    float distance_top = (length(observer_to_top) / distance_observer_to_tangent) * distance_observer_to_secant; // distance from observer to point on tangent
    vec3 top_on_secant = normalize(observer_to_top) * distance_top + vec3(gazePosition);

    // bottom limit
    vec3 bottom_cylinder = vec3(0, -screen_height / 2.0, -distance_center_to_tangent);
    vec3 observer_to_bottom = bottom_cylinder - vec3(gazePosition);
    float distance_bottom = (length(observer_to_bottom) / distance_observer_to_tangent) * distance_observer_to_secant; // distance from observer to point on tangent
    vec3 bottom_on_secant = normalize(observer_to_bottom) * distance_bottom + vec3(gazePosition);

    float top = max(top_on_secant.y, screen_height / 2.0);
    float bottom = min(bottom_on_secant.y, -screen_height / 2.0);

    // position on actual curved screen (distributed equally over arc length)
    vec2 inPosition = texCoord * 2.0 - 1.0;
    if (FLIP_UV_FROM_OGL) {
        inPosition.y *= -1.0; // flip OGL texture coordinates
    } 
    vec3 point_on_screen = vec3(
        sin(half_angle_rad * inPosition.x) * CURVATURE_RADIUS,
        screen_height / 2.0 * inPosition.y,
        -cos(half_angle_rad * inPosition.x) * CURVATURE_RADIUS
    );

    // calculate intersection with near plane
    vec3 ray = vec3(point_on_screen - gazePosition.xyz);

    vec3 point_on_near_plane;
    if (INSET_PROJECTION) {
        point_on_near_plane = rayPlaneInersection(normalize(ray), gazePosition.xyz, vec3(0, 0, 1), distance_center_to_tangent);
    } else {
        point_on_near_plane = rayPlaneInersection(normalize(ray), gazePosition.xyz, vec3(0, 0, 1), distance_center_to_secant);
    }

    // use calculated position on near plane as the basis for texture coordinates
    vec2 half_value_range = vec2(half_secant_length, (top - bottom) / 2.0);
    // The vertical center on the near plane (image) is offset from the vertical center on the actual screen. We need
    // to add the offset to the point on the near plane so that the transformation of the coordinates to [0, 1] is correct.
    vec2 offset = vec2(0.0, -mix(bottom, top, 0.5));

    vec2 outputCoord = (point_on_near_plane.xy + offset + half_value_range) / (2.0 * half_value_range);
    if (FLIP_UV_FROM_OGL) {
        outputCoord.y = 1.0 - outputCoord.y; // flip output coordinates back so the texture is sampled correctly
    } 

    return outputCoord;
}

void main() {
    vec2 correctedTexCoord = undistorTextureCoordinates(v_texcoord);

    if (BICUBIC_FILTERING) {
        outColor = textureBicubic(tex, correctedTexCoord);
    } else {
        outColor = texture(tex, correctedTexCoord);
    }
}

