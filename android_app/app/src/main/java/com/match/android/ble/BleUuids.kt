package com.match.android.ble

import java.util.UUID
import java.util.UUID.fromString

object BleUuids  {
    val SERVICE_UUID: UUID = fromString("85f7d963-2581-4791-af25-8106929aa1a0")
    val CHARACTERISTIC_UUID: UUID = fromString("0be778a3-2096-46c8-82c9-3a9d63376512")
}
