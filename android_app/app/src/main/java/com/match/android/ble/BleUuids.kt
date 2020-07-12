package com.match.android.ble

import java.util.UUID
import java.util.UUID.fromString

object BleUuids  {
    // Can't get other service UUIDs to work with advertisement data (Start advertising failure: 1)
//    val SERVICE_UUID: UUID = fromString("0000C019-0000-1000-8000-00905F9B34FB")
    val SERVICE_UUID: UUID = fromString("0000C019-0000-1000-8000-00805F9B34FB")

    val CHARACTERISTIC_UUID: UUID = fromString("0be778a3-2096-46c8-82c9-3a9d63376512")
}
