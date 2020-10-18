package com.match.android.ble

import kotlin.math.pow

const val defaultMeasuredRssiAtOneMeter: Int = -67

object DistanceCalculator {
    fun estimateDistance(rssi: Int, txPowerLevel: Int?, isAndroid: Boolean): Double = estimateDistance(
        rssi,
        measuredRssiAtOneMeter(txPowerLevel, isAndroid)
    )

    private fun estimateDistance(rssi: Int, measuredRSSIAtOneMeter: Int = defaultMeasuredRssiAtOneMeter,
                                 environmentalFactor: Double = 2.0): Double = when {
        rssi >= 20.0 -> -1.0
        environmentalFactor !in 2.0..4.0 -> -1.0
        else -> 10.0.pow((measuredRSSIAtOneMeter - rssi) / (10.0 * environmentalFactor))
    }

    private fun measuredRssiAtOneMeter(txPowerLevel: Int?, isAndroid: Boolean = false): Int {
        var effectiveTxPowerLevel = txPowerLevel
        if (effectiveTxPowerLevel == null) {
            effectiveTxPowerLevel = if (!isAndroid) { 11 } else { 12 }
        }

        if (effectiveTxPowerLevel < 0) {
            effectiveTxPowerLevel += 20
        }

        return when (effectiveTxPowerLevel) {
            in 12..20 -> defaultMeasuredRssiAtOneMeter
            in 9..12 -> -71
            else -> -86
        }
    }
}
