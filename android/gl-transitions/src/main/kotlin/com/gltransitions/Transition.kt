package com.gltransitions

/** The gl-transitions collection: [all] the transitions, or one by [name][named]. */
object GLTransitions {
    /** Version of the gl-transitions npm package the transitions come from. */
    const val CATALOG_VERSION: String = com.gltransitions.generated.CATALOG_VERSION

    /** Every transition, sorted by name. */
    @JvmStatic
    val all: List<Transition> by lazy { com.gltransitions.generated.catalog() }

    private val byName by lazy { all.associateBy { it.name } }

    /** The transition with this name (as in gl-transitions.com), if the collection has it. */
    @JvmStatic
    fun named(name: String): Transition? = byName[name]
}

/** A transition between two images: its metadata, parameters and AGSL shader. */
class Transition internal constructor(
    val name: String,
    val author: String,
    val license: String,
    val description: String?,
    val tags: List<String>,
    /** The parameters, in declaration order. */
    val params: List<Param>,
    /** The extra images the shader samples besides `from` and `to` (e.g. `luma`), in order. */
    val textures: List<String>,
) {
    /**
     * The AGSL (SkSL) shader for [android.graphics.RuntimeShader]: children `_from`, `_to` and
     * one per [textures], images drawn at the output size; uniforms `_resolution` (output size in
     * pixels), `progress`, `ratio`, then each parameter by name (`bool` parameters are `int`).
     */
    val agsl: String by lazy {
        val stream = Transition::class.java.getResourceAsStream("sksl/$name.sksl")
            ?: error("the AGSL source of $name is missing from the library")
        stream.bufferedReader().use { it.readText() }
    }

    /** The parameter with this name. */
    fun param(name: String): Param? = params.firstOrNull { it.name == name }

    /** Each parameter's default value. */
    val defaultParams: Map<String, ParamValue> get() = params.associate { it.name to it.default }

    override fun equals(other: Any?) = other is Transition && other.name == name
    override fun hashCode() = name.hashCode()
    override fun toString() = "Transition($name)"
}

/** A transition parameter. */
class Param internal constructor(
    val name: String,
    val type: ParamType,
    val default: ParamValue,
    val min: Float?,
    val max: Float?,
    val step: Float?,
    /** A `vec3` or `vec4` meant as an RGB(A) color. */
    val isColor: Boolean,
    val description: String?,
) {
    override fun toString() = "Param($name: $type = $default)"
}

enum class ParamType(internal val size: Int, internal val integer: Boolean) {
    FLOAT(1, false), VEC2(2, false), VEC3(3, false), VEC4(4, false),
    INT(1, true), IVEC2(2, true), IVEC3(3, true), IVEC4(4, true),
    BOOL(1, true),
}

/** A parameter value: `ParamValue.float(0.5f)`, `ParamValue.ivec2(4, 4)`, `ParamValue.bool(true)`… */
class ParamValue private constructor(
    val type: ParamType,
    internal val floats: FloatArray,
    internal val ints: IntArray,
) {
    /** The components of a `float` or `vec*` value. */
    fun floats(): FloatArray = floats.copyOf()

    /** The components of an `int`, `ivec*` or `bool` value (`bool` is 0 or 1, as the shaders take it). */
    fun ints(): IntArray = ints.copyOf()

    override fun equals(other: Any?) =
        other is ParamValue && other.type == type && other.floats.contentEquals(floats) && other.ints.contentEquals(ints)

    override fun hashCode() = 31 * (31 * type.hashCode() + floats.contentHashCode()) + ints.contentHashCode()

    override fun toString() = when {
        type == ParamType.BOOL -> "bool(${ints[0] != 0})"
        type.integer -> "${type.name.lowercase()}(${ints.joinToString()})"
        else -> "${type.name.lowercase()}(${floats.joinToString()})"
    }

    companion object {
        private fun f(type: ParamType, vararg v: Float) = ParamValue(type, v, IntArray(0))
        private fun i(type: ParamType, vararg v: Int) = ParamValue(type, FloatArray(0), v)

        @JvmStatic fun float(x: Float) = f(ParamType.FLOAT, x)
        @JvmStatic fun vec2(x: Float, y: Float) = f(ParamType.VEC2, x, y)
        @JvmStatic fun vec3(x: Float, y: Float, z: Float) = f(ParamType.VEC3, x, y, z)
        @JvmStatic fun vec4(x: Float, y: Float, z: Float, w: Float) = f(ParamType.VEC4, x, y, z, w)
        @JvmStatic fun int(x: Int) = i(ParamType.INT, x)
        @JvmStatic fun ivec2(x: Int, y: Int) = i(ParamType.IVEC2, x, y)
        @JvmStatic fun ivec3(x: Int, y: Int, z: Int) = i(ParamType.IVEC3, x, y, z)
        @JvmStatic fun ivec4(x: Int, y: Int, z: Int, w: Int) = i(ParamType.IVEC4, x, y, z, w)
        @JvmStatic fun bool(x: Boolean) = i(ParamType.BOOL, if (x) 1 else 0)
    }
}
