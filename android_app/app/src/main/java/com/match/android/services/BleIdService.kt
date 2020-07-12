package com.match.android.services

import com.match.android.services.BleIdSerializer.fromString
import com.match.android.services.BleIdSerializer.toString
import com.match.android.system.Preferences
import com.match.android.system.PreferencesKey
import io.reactivex.Observable
import io.reactivex.subjects.PublishSubject
import java.nio.charset.Charset
import java.nio.charset.Charset.forName
import java.util.UUID.randomUUID

data class BleId(
    val data: ByteArray
) {
    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (javaClass != other?.javaClass) return false
        other as BleId
        if (!data.contentEquals(other.data)) return false
        return true
    }

    override fun hashCode(): Int = data.contentHashCode()
    override fun toString(): String = toString(this)
}

object BleIdSerializer {
    private val charset: Charset = forName("utf-8")

    fun toString(bleId: BleId): String =
        String(bleId.data, charset)

    fun fromString(string: String): BleId =
        BleId(string.toByteArray(charset))

    // Here, since we want to ensure the string it's based on has the correct encoding.
    fun randomValidStringBasedBleId(): BleId =
        fromString(randomUUID().toString())
}

interface BleIdService {
    val myId: Observable<BleId>

    fun bleId(): BleId
}

class BleIdServiceImpl(private val preferences: Preferences) : BleIdService {
    override val myId: PublishSubject<BleId> = PublishSubject.create()

    override fun bleId(): BleId =
        preferences.getString(PreferencesKey.BleId)?.let {
            fromString(it)
        } ?: BleIdSerializer.randomValidStringBasedBleId().also {
            preferences.putString(PreferencesKey.BleId, toString(it))
        }.also {
            // Assumption: bleId() will be advertised
            myId.onNext(it)
        }
}
