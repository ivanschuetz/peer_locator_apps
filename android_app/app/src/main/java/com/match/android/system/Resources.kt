package com.match.android.system

import android.content.Context
import android.graphics.drawable.Drawable
import androidx.annotation.DrawableRes

class Resources(private val context: Context) {
    fun getString(id: Int, vararg args: Any): String = context.getString(id, *args)

    fun getDrawable(@DrawableRes id: Int): Drawable? = context.getDrawable(id)

    fun getQuantityString(id: Int, quantity: Int): String =
        context.resources.getQuantityString(id, quantity, quantity.toString())
}
