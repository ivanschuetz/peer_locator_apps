package com.match.android.system

import android.app.Application
import android.content.SharedPreferences
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey

enum class SecurePreferencesKey {
    PublicKey, PrivateKey
}

interface SecurePreferences {
    fun getString(key: SecurePreferencesKey): String?
    fun putString(key: SecurePreferencesKey, value: String?)
}

class SecurePreferencesImpl(app: Application): SecurePreferences {
    private val sharedPreferences = getEncryptedPrefs(app)

    override fun getString(key: SecurePreferencesKey): String? =
        sharedPreferences.getString(key.toString(), null)

    override fun putString(key: SecurePreferencesKey, value: String?) {
        putOrClear(key, value) {
            sharedPreferences.edit().putString(key.toString(), it).apply()
        }
    }

    private fun <T> putOrClear(key: SecurePreferencesKey, obj: T?, put: (T) -> Unit) {
        if (obj != null) {
            put(obj)
        } else {
            clear(key)
        }
    }

    private fun clear(key: SecurePreferencesKey) {
        sharedPreferences.edit().remove(key.toString()).apply()
    }

    private fun getEncryptedPrefs(androidApplication: Application): SharedPreferences {
        val spec = KeyGenParameterSpec.Builder(
            MasterKey.DEFAULT_MASTER_KEY_ALIAS,
            KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT
        )
            .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
            .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
            .setKeySize(256)
            .build()

        val masterKey = MasterKey.Builder(androidApplication)
            .setKeyGenParameterSpec(spec)
            .build()

        return EncryptedSharedPreferences.create(
            androidApplication,
            "match-prefs",
            masterKey,
            EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
            EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
        )
    }
}
