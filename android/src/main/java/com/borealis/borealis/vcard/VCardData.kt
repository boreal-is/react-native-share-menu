package com.borealis.borealis.vcard


import ezvcard.VCard
import java.io.Serializable

class VCardData(vCard: VCard, val photoPath: String?, val photoMime: String?) : Serializable {
    var firstName = vCard.structuredName.given
    var lastName = vCard.structuredName.family
    var phone: String?
    var email: String?
    var organization = vCard.organization?.values?.firstOrNull()
    var position = vCard.titles?.firstOrNull()?.value
    var address: String? = null

    init {
        vCard.telephoneNumbers?.sortBy { it.pref }
        this.phone = vCard.telephoneNumbers?.firstOrNull()?.text

        vCard.emails?.sortBy { it.pref }
        this.email = vCard.emails?.getOrNull(0)?.value

        vCard.addresses?.sortBy { it.pref }
        val addressComponents = vCard.addresses.getOrNull(0)
        this.address = if (addressComponents == null) {
            null
        } else {
            arrayOf(
                    addressComponents.streetAddress,
                    addressComponents.poBox,
                    addressComponents.postalCode,
                    addressComponents.locality,
                    addressComponents.region,
                    addressComponents.country
            ).filterNotNull().joinToString()
        }
    }
}
