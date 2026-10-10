package com.andymarrow.unsung.audio

import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.sin

/** RBJ cookbook biquad, Direct Form I. */
class Biquad private constructor(
    private val b0: Double,
    private val b1: Double,
    private val b2: Double,
    private val a1: Double,
    private val a2: Double,
) {
    private var x1 = 0.0
    private var x2 = 0.0
    private var y1 = 0.0
    private var y2 = 0.0

    fun process(x: Double): Double {
        val y = b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
        x2 = x1; x1 = x
        y2 = y1; y1 = y
        return y
    }

    companion object {
        private const val Q = 0.7071

        fun lowpass(rate: Int, hz: Double): Biquad {
            val w = 2 * PI * hz / rate
            val alpha = sin(w) / (2 * Q)
            val c = cos(w)
            val a0 = 1 + alpha
            return Biquad((1 - c) / 2 / a0, (1 - c) / a0, (1 - c) / 2 / a0, -2 * c / a0, (1 - alpha) / a0)
        }

        fun highpass(rate: Int, hz: Double): Biquad {
            val w = 2 * PI * hz / rate
            val alpha = sin(w) / (2 * Q)
            val c = cos(w)
            val a0 = 1 + alpha
            return Biquad((1 + c) / 2 / a0, -(1 + c) / a0, (1 + c) / 2 / a0, -2 * c / a0, (1 - alpha) / a0)
        }
    }
}

/** Damped feedback comb filter (Freeverb). */
private class Comb(size: Int, private val feedback: Double, private val damp: Double) {
    private val buf = DoubleArray(size)
    private var i = 0
    private var store = 0.0

    fun process(x: Double): Double {
        val out = buf[i]
        store = out * (1 - damp) + store * damp
        buf[i] = x + store * feedback
        if (++i >= buf.size) i = 0
        return out
    }
}

private class Allpass(size: Int) {
    private val buf = DoubleArray(size)
    private var i = 0

    fun process(x: Double): Double {
        val b = buf[i]
        buf[i] = x + b * 0.5
        if (++i >= buf.size) i = 0
        return b - x
    }
}

/** A small Freeverb: 4 combs + 2 allpasses per channel, warm room. */
class Reverb(rate: Int, spread: Int) {
    private val scale = rate / 44_100.0
    private val combs = intArrayOf(1116, 1188, 1277, 1356).map {
        Comb(((it + spread) * scale).toInt().coerceAtLeast(1), 0.84, 0.25)
    }
    private val allpasses = intArrayOf(556, 441).map {
        Allpass(((it + spread) * scale).toInt().coerceAtLeast(1))
    }

    fun process(x: Double): Double {
        var y = 0.0
        val input = x * 0.015
        for (c in combs) y += c.process(input)
        for (a in allpasses) y = a.process(y)
        return y
    }
}

/** Single-tap feedback echo. */
class Echo(rate: Int, delayMs: Int, private val feedback: Double) {
    private val buf = DoubleArray((rate * delayMs / 1000).coerceAtLeast(1))
    private var i = 0

    fun process(x: Double): Double {
        val out = buf[i]
        buf[i] = x + out * feedback
        if (++i >= buf.size) i = 0
        return out
    }
}

/** Soft knee limiter: transparent below 0.8, smoothly approaches 1.0. */
fun softLimit(x: Double): Double {
    val a = abs(x)
    if (a <= 0.8) return x
    val over = a - 0.8
    val limited = 0.8 + over / (1 + over / 0.2)
    return if (x < 0) -limited else limited
}
