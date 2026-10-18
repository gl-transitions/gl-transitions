import type { Transition as CatalogTransition } from "gl-transitions";
import type { ParamInput } from "./transition-types.generated.ts";

// Draws a gl-transition with WebGL 2, as the GL Transition Specification v1 describes it: the
// GLSL source of the catalog, wrapped with `from`, `to`, `progress` and `ratio`.

const VERTEX = `attribute vec2 _p;
varying vec2 _uv;
void main() {
  gl_Position = vec4(_p, 0.0, 1.0);
  _uv = (_p + 1.0) * 0.5;
}`;

const fragment = (glsl: string) => `precision highp float;
varying vec2 _uv;
uniform sampler2D from, to;
uniform float progress, ratio;
vec4 getFromColor(vec2 uv) { return texture2D(from, uv); }
vec4 getToColor(vec2 uv) { return texture2D(to, uv); }
${glsl}
void main() { gl_FragColor = transition(_uv); }`;

export interface DrawOptions {
  transition: CatalogTransition;
  /** The outgoing image (upright), or null for transparent. */
  from: TexImageSource | null;
  /** The incoming image (upright), or null for transparent. */
  to: TexImageSource | null;
  progress: number;
  width: number;
  height: number;
  params: { [name: string]: ParamInput | undefined };
  /** The extra textures of the transition (`transition.textures`), by name; null for transparent. */
  textures: { [name: string]: TexImageSource | null };
}

function compile(gl: WebGL2RenderingContext, type: number, source: string, name: string): WebGLShader {
  if (gl.isContextLost()) throw new Error("gl-transitions: the WebGL context was lost");
  const shader = gl.createShader(type)!;
  gl.shaderSource(shader, source);
  gl.compileShader(shader);
  if (!gl.getShaderParameter(shader, gl.COMPILE_STATUS)) {
    const log = gl.getShaderInfoLog(shader);
    gl.deleteShader(shader);
    throw new Error(`gl-transitions: '${name}' failed to compile: ${log}`);
  }
  return shader;
}

// Number of values of each parameter type.
const SIZES: { [type: string]: number } = {
  vec2: 2,
  vec3: 3,
  vec4: 4,
  ivec2: 2,
  ivec3: 3,
  ivec4: 4,
  mat2: 4,
  mat3: 9,
  mat4: 16,
};

type Setter = (gl: WebGL2RenderingContext, location: WebGLUniformLocation | null, values: number[]) => void;
// By parameter type; bool is an int uniform. A null location (optimized out) is ignored by WebGL.
const SETTERS: { [type: string]: Setter } = {
  float: (gl, l, v) => gl.uniform1fv(l, v),
  int: (gl, l, v) => gl.uniform1iv(l, v),
  bool: (gl, l, v) => gl.uniform1iv(l, v),
  vec2: (gl, l, v) => gl.uniform2fv(l, v),
  vec3: (gl, l, v) => gl.uniform3fv(l, v),
  vec4: (gl, l, v) => gl.uniform4fv(l, v),
  ivec2: (gl, l, v) => gl.uniform2iv(l, v),
  ivec3: (gl, l, v) => gl.uniform3iv(l, v),
  ivec4: (gl, l, v) => gl.uniform4iv(l, v),
  mat2: (gl, l, v) => gl.uniformMatrix2fv(l, false, v),
  mat3: (gl, l, v) => gl.uniformMatrix3fv(l, false, v),
  mat4: (gl, l, v) => gl.uniformMatrix4fv(l, false, v),
};

/**
 * A WebGL 2 renderer of gl-transitions: compiles each transition once, on first use. Remotion
 * may draw again after `dispose()` (React re-running an effect), so everything is recreated lazily.
 */
export function createRenderer(gl: WebGL2RenderingContext) {
  const programs = new Map<string, WebGLProgram>();
  let buffer: WebGLBuffer | null = null;
  const textures: WebGLTexture[] = [];
  // The image last uploaded to each texture unit: the extra textures don't change between frames.
  const uploaded: (TexImageSource | null)[] = [];

  function getProgram(transition: CatalogTransition): WebGLProgram {
    let program = programs.get(transition.name);
    if (!program) {
      program = gl.createProgram()!;
      let vertex: WebGLShader | null = null;
      let frag: WebGLShader | null = null;
      try {
        vertex = compile(gl, gl.VERTEX_SHADER, VERTEX, transition.name);
        frag = compile(gl, gl.FRAGMENT_SHADER, fragment(transition.glsl), transition.name);
        gl.attachShader(program, vertex);
        gl.attachShader(program, frag);
        gl.bindAttribLocation(program, 0, "_p");
        gl.linkProgram(program);
        if (!gl.getProgramParameter(program, gl.LINK_STATUS)) {
          throw new Error(`gl-transitions: '${transition.name}' failed to link: ${gl.getProgramInfoLog(program)}`);
        }
      } catch (error) {
        gl.deleteProgram(program);
        throw error;
      } finally {
        gl.deleteShader(vertex);
        gl.deleteShader(frag);
      }
      programs.set(transition.name, program);
    }
    return program;
  }

  // Binds `image` to texture `unit`, flipped so that uv (0, 0) is its bottom-left corner.
  function bindImage(unit: number, image: TexImageSource | null, cached = false) {
    while (textures.length <= unit) {
      const texture = gl.createTexture()!;
      gl.bindTexture(gl.TEXTURE_2D, texture);
      gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
      gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
      gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
      gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
      textures.push(texture);
    }
    gl.activeTexture(gl.TEXTURE0 + unit);
    gl.bindTexture(gl.TEXTURE_2D, textures[unit]);
    if (cached && unit in uploaded && uploaded[unit] === image) return;
    uploaded[unit] = image;
    if (image) {
      gl.pixelStorei(gl.UNPACK_FLIP_Y_WEBGL, true);
      gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, gl.RGBA, gl.UNSIGNED_BYTE, image);
      gl.pixelStorei(gl.UNPACK_FLIP_Y_WEBGL, false);
    } else {
      gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, 1, 1, 0, gl.RGBA, gl.UNSIGNED_BYTE, new Uint8Array(4));
    }
  }

  return {
    draw({ transition, from, to, progress, width, height, params, textures: extra }: DrawOptions) {
      const program = getProgram(transition);
      const uniform = (name: string) => gl.getUniformLocation(program, name);
      gl.viewport(0, 0, width, height);
      gl.useProgram(program);
      bindImage(0, from);
      gl.uniform1i(uniform("from"), 0);
      bindImage(1, to);
      gl.uniform1i(uniform("to"), 1);
      gl.uniform1f(uniform("progress"), progress);
      gl.uniform1f(uniform("ratio"), width / height);
      for (const [name, param] of Object.entries(transition.params)) {
        const value = params[name] ?? param.default;
        if (value === undefined) {
          throw new Error(`gl-transitions: parameter '${name}' of '${transition.name}' has no default value`);
        }
        const values = [value].flat().map(Number);
        if (values.length !== (SIZES[param.type] ?? 1)) {
          throw new Error(
            `gl-transitions: parameter '${name}' of '${transition.name}' is a ${param.type}, got ${JSON.stringify(value)}`,
          );
        }
        SETTERS[param.type](gl, uniform(name), values);
      }
      transition.textures.forEach((name, i) => {
        bindImage(2 + i, extra[name] ?? null, true);
        gl.uniform1i(uniform(name), 2 + i);
      });
      if (!buffer) {
        buffer = gl.createBuffer();
        gl.bindBuffer(gl.ARRAY_BUFFER, buffer);
        gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([-1, -1, 3, -1, -1, 3]), gl.STATIC_DRAW);
      }
      gl.bindBuffer(gl.ARRAY_BUFFER, buffer);
      gl.enableVertexAttribArray(0);
      gl.vertexAttribPointer(0, 2, gl.FLOAT, false, 0, 0);
      gl.drawArrays(gl.TRIANGLES, 0, 3);
    },
    clear() {
      gl.clearColor(0, 0, 0, 0);
      gl.clear(gl.COLOR_BUFFER_BIT);
    },
    dispose() {
      for (const program of programs.values()) gl.deleteProgram(program);
      programs.clear();
      for (const texture of textures) gl.deleteTexture(texture);
      textures.length = 0;
      uploaded.length = 0;
      gl.deleteBuffer(buffer);
      buffer = null;
    },
  };
}
