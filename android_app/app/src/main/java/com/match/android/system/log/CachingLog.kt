package com.match.android.system.log

import com.match.android.system.log.LogLevel.D
import com.match.android.system.log.LogLevel.E
import com.match.android.system.log.LogLevel.I
import com.match.android.system.log.LogLevel.V
import com.match.android.system.log.LogLevel.W
import com.match.android.ui.common.LimitedSizeQueue
import kotlinx.coroutines.channels.ConflatedBroadcastChannel
import kotlinx.coroutines.channels.sendBlocking
import java.util.Date

class CachingLog : Log {
    val logs = ConflatedBroadcastChannel<LimitedSizeQueue<LogMessage>>(
        LimitedSizeQueue(1000)
    )

    override fun setup() {}

    override fun v(message: String, tag: LogTag?) {
        log(LogMessage(V, addTag(tag, message)))
    }

    override fun d(message: String, tag: LogTag?) {
        log(LogMessage(D, addTag(tag, message)))
    }

    override fun i(message: String, tag: LogTag?) {
        log(LogMessage(I, addTag(tag, message)))
    }

    override fun w(message: String, tag: LogTag?) {
        log(LogMessage(W, addTag(tag, message)))
    }

    override fun e(message: String, tag: LogTag?) {
        log(LogMessage(E, addTag(tag, message)))
    }

    private fun log(message: LogMessage) {
        logs.sendBlocking(logs.value.apply { add(message) })
    }

    private fun addTag(tag: LogTag?, message: String) =
        (tag?.let { "$it - " } ?: "") + message
}

data class LogMessage(val level: LogLevel, val text: String, val time: Date = Date())

enum class LogLevel(val text: String) {
    V("Verbose"),
    D("Debug"),
    I("Info"),
    W("Warn"),
    E("Error")
}
