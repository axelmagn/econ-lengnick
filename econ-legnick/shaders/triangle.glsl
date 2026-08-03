@vs vs
in vec3 position;
in vec4 color;

out vec4 interpolated_color;

void main() {
    gl_Position = vec4(position, 1.0);
    interpolated_color = color;
}
@end

@fs fs
in vec4 interpolated_color;
out vec4 frag_color;

void main() {
    frag_color = interpolated_color;
}
@end

@program triangle vs fs
