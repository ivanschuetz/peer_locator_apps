package com.match.android.system

import com.match.android.system.SecurePreferencesKey.PrivateKey
import com.match.android.system.SecurePreferencesKey.PublicKey
import com.match.android.system.log.log
import java.security.KeyPair
import java.security.KeyPairGenerator

class KeyManager(private val preferences: SecurePreferences) {

    fun keyPair(): KeyPair? {
        val privateKey = preferences.getString(PrivateKey)
        val publicKey = preferences.getString(PublicKey)

        when {
            privateKey == null && publicKey == null -> generateAndStoreKeyPair()
            privateKey != null && publicKey != null ->
                KeyPair(PublicKey(publicKey), privateKey)


        }

        val keyPair = generateAndStoreKeyPair()

        return keyPair
    }

    private fun generateAndStoreKeyPair(): KeyPair? {
        // TODO investigate when error can happen and
        val keyPair = generateKeyPair() ?: error("Couldn't generate key pair")
        preferences.putString(PublicKey, keyPair.public.toString())
        return keyPair
    }

    private fun generateKeyPair(): KeyPair? = try {
        val kpg = KeyPairGenerator.getInstance("RSA")
        kpg.initialize(2048)
        kpg.generateKeyPair()
    } catch (e: Throwable) {
        e.printStackTrace()
        null
    }
}
