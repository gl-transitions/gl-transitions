package com.gltransitions

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class CatalogTest {
    @Test
    fun catalog() {
        val all = GLTransitions.all
        assertTrue(all.size > 100)
        assertEquals(all.size, all.map { it.name }.toSet().size)
        assertTrue(GLTransitions.CATALOG_VERSION.isNotEmpty())
        for (transition in all) {
            assertEquals(transition, GLTransitions.named(transition.name))
            assertTrue(transition.name, transition.agsl.contains("uniform shader _from;"))
            for (name in transition.textures) {
                assertTrue("${transition.name}.$name", transition.agsl.contains("uniform shader $name;"))
            }
            for (param in transition.params) {
                assertEquals("${transition.name}.${param.name}", param.type, param.default.type)
            }
        }
        assertNull(GLTransitions.named("nope"))
    }

    @Test
    fun params() {
        val gridFlip = GLTransitions.named("GridFlip")!!
        assertEquals(ParamValue.ivec2(4, 4), gridFlip.param("size")!!.default)
        assertEquals(ParamValue.vec4(0f, 0f, 0f, 1f), gridFlip.defaultParams["bgcolor"])
        assertTrue(gridFlip.param("bgcolor")!!.isColor)
        assertEquals(listOf(1), ParamValue.bool(true).ints().toList())
        assertEquals("ivec2(4, 4)", ParamValue.ivec2(4, 4).toString())
    }

    @Test
    fun licenses() {
        val notices = Transition::class.java.getResourceAsStream("LICENSES.md")!!.bufferedReader().use { it.readText() }
        for (transition in GLTransitions.all.filter { it.license != "MIT" }) {
            assertTrue(transition.name, notices.contains("## ${transition.name}\n"))
        }
    }
}
