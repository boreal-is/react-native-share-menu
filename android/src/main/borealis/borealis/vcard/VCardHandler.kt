package com.borealis.borealis.vcard

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import ezvcard.Ezvcard
import java.io.File
import java.io.FileNotFoundException
import java.io.IOException
import java.io.InputStream
import java.util.*

class VCardHandler(private val context: Context) {
    fun processVCard(extras: Bundle): VCardData? {
        val uri = extras.get(Intent.EXTRA_STREAM) as Uri
        val cr = this.context.contentResolver
        var stream: InputStream? = null
        try {
            stream = cr.openInputStream(uri)
        } catch (e: FileNotFoundException) {
            // TODO Auto-generated catch block
            e.printStackTrace()
        }

        val content: String?
        try {
            content = String(stream!!.readBytes())
        } catch (e: IOException) {
            // TODO Auto-generated catch block
            e.printStackTrace()
            return null
        } finally {
            stream!!.close()
        }

        val vCard = Ezvcard.parse(content).first()

        val photo = vCard.photos.getOrNull(0)
        val photoPath = if (photo != null && photo.data != null && photo.contentType != null && photo.contentType.extension != null && photo.contentType.mediaType != null) {
            val file = File.createTempFile(UUID.randomUUID().toString(), ".${photo.contentType.extension}", this.context.cacheDir)
            file.writeBytes(photo.data)
            "file://${file.absolutePath}"
        } else {
            null
        }
        val photoMime = if (photoPath != null) photo!!.contentType.mediaType else null

        return VCardData(vCard, photoPath, photoMime)
    }
}