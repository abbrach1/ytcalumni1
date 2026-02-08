package com.ytcalumni.app.models

import com.google.firebase.firestore.DocumentSnapshot
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

// MARK: - Shiur Model
data class Shiur(
    val id: String? = null,
    val title: String = "",
    val rebbe: String = "",
    val date: String = "",
    val tags: List<String> = emptyList(),
    val audioUrl: String? = null,
    val pdfUrl: String? = null,
    val description: String? = null,
    val playCount: Int? = null,
    val downloadCount: Int? = null,
    val series: String? = null
) {
    val formattedDate: String
        get() {
            return try {
                val inputFormat = SimpleDateFormat("yyyy-MM-dd", Locale.US)
                val outputFormat = SimpleDateFormat("MMMM d, yyyy", Locale.US)
                val parsed = inputFormat.parse(date)
                parsed?.let { outputFormat.format(it) } ?: date
            } catch (e: Exception) {
                date
            }
        }

    val shortDate: String
        get() {
            return try {
                val inputFormat = SimpleDateFormat("yyyy-MM-dd", Locale.US)
                val outputFormat = SimpleDateFormat("MMM d, yyyy", Locale.US)
                val parsed = inputFormat.parse(date)
                parsed?.let { outputFormat.format(it) } ?: date
            } catch (e: Exception) {
                date
            }
        }

    companion object {
        fun fromDocument(doc: DocumentSnapshot): Shiur? {
            val data = doc.data ?: return null
            return Shiur(
                id = doc.id,
                title = data["title"] as? String ?: "",
                rebbe = data["rebbe"] as? String ?: "",
                date = data["date"] as? String ?: "",
                tags = (data["tags"] as? List<*>)?.filterIsInstance<String>() ?: emptyList(),
                audioUrl = data["audioUrl"] as? String,
                pdfUrl = data["pdfUrl"] as? String,
                description = data["description"] as? String,
                playCount = (data["playCount"] as? Long)?.toInt(),
                downloadCount = (data["downloadCount"] as? Long)?.toInt(),
                series = data["series"] as? String
            )
        }
    }
}

// MARK: - Event Model
data class Event(
    val id: String? = null,
    val eventName: String = "",
    val personFamily: String = "",
    val type: String = "",
    val date: String = "",
    val location: String = "",
    val time: String? = null,
    val imageUrl: String? = null,
    val description: String? = null
) {
    val formattedDate: String
        get() {
            return try {
                val inputFormat = SimpleDateFormat("yyyy-MM-dd", Locale.US)
                val outputFormat = SimpleDateFormat("MMMM d, yyyy", Locale.US)
                val parsed = inputFormat.parse(date)
                parsed?.let { outputFormat.format(it) } ?: date
            } catch (e: Exception) {
                date
            }
        }

    val dayNumber: String
        get() {
            return try {
                val inputFormat = SimpleDateFormat("yyyy-MM-dd", Locale.US)
                val outputFormat = SimpleDateFormat("d", Locale.US)
                val parsed = inputFormat.parse(date)
                parsed?.let { outputFormat.format(it) } ?: ""
            } catch (e: Exception) {
                ""
            }
        }

    val monthAbbreviation: String
        get() {
            return try {
                val inputFormat = SimpleDateFormat("yyyy-MM-dd", Locale.US)
                val outputFormat = SimpleDateFormat("MMM", Locale.US)
                val parsed = inputFormat.parse(date)
                parsed?.let { outputFormat.format(it).uppercase() } ?: ""
            } catch (e: Exception) {
                ""
            }
        }

    val isPast: Boolean
        get() {
            return try {
                val inputFormat = SimpleDateFormat("yyyy-MM-dd", Locale.US)
                val eventDate = inputFormat.parse(date)
                eventDate?.before(Date()) ?: false
            } catch (e: Exception) {
                false
            }
        }

    companion object {
        fun fromDocument(doc: DocumentSnapshot): Event? {
            val data = doc.data ?: return null
            return Event(
                id = doc.id,
                eventName = data["eventName"] as? String ?: "",
                personFamily = data["personFamily"] as? String ?: "",
                type = data["type"] as? String ?: "",
                date = data["date"] as? String ?: "",
                location = data["location"] as? String ?: "",
                time = data["time"] as? String,
                imageUrl = data["imageUrl"] as? String,
                description = data["description"] as? String
            )
        }
    }
}

// MARK: - Announcement Model
data class Announcement(
    val id: String? = null,
    val title: String = "",
    val content: String = "",
    val type: String = "announcement",
    val date: String = "",
    val enabled: Boolean = false
) {
    val isMazelTov: Boolean get() = type == "mazel_tov"

    companion object {
        fun fromDocument(doc: DocumentSnapshot): Announcement? {
            val data = doc.data ?: return null
            return Announcement(
                id = doc.id,
                title = data["title"] as? String ?: "",
                content = data["content"] as? String ?: "",
                type = data["type"] as? String ?: "announcement",
                date = data["date"] as? String ?: "",
                enabled = data["enabled"] as? Boolean ?: false
            )
        }
    }
}

// MARK: - Carousel Image Model
data class CarouselImage(
    val id: String? = null,
    val url: String = "",
    val caption: String? = null,
    val order: Int = 0
) {
    companion object {
        fun fromDocument(doc: DocumentSnapshot): CarouselImage? {
            val data = doc.data ?: return null
            return CarouselImage(
                id = doc.id,
                url = data["url"] as? String ?: "",
                caption = data["caption"] as? String,
                order = (data["order"] as? Long)?.toInt() ?: 0
            )
        }
    }
}

// MARK: - Alumni Photo Model
data class AlumniPhoto(
    val id: String? = null,
    val url: String = "",
    val caption: String? = null,
    val name: String? = null,
    val year: String? = null,
    val order: Int = 0
) {
    companion object {
        fun fromDocument(doc: DocumentSnapshot): AlumniPhoto? {
            val data = doc.data ?: return null
            return AlumniPhoto(
                id = doc.id,
                url = data["url"] as? String ?: "",
                caption = data["caption"] as? String,
                name = data["name"] as? String,
                year = data["year"] as? String,
                order = (data["order"] as? Long)?.toInt() ?: 0
            )
        }
    }
}

// MARK: - Alumni Contact Model
data class AlumniContact(
    val id: String? = null,
    val name: String = "",
    val email: String? = null,
    val phone: String? = null,
    val location: String = "",
    val submittedAt: String? = null
) {
    companion object {
        fun fromDocument(doc: DocumentSnapshot): AlumniContact? {
            val data = doc.data ?: return null
            return AlumniContact(
                id = doc.id,
                name = data["name"] as? String ?: "",
                email = data["email"] as? String,
                phone = data["phone"] as? String,
                location = data["location"] as? String ?: "",
                submittedAt = data["submittedAt"] as? String
            )
        }
    }
}

// MARK: - Rebbe Model
data class Rebbe(
    val id: String? = null,
    val name: String = "",
    val title: String = "",
    val email: String? = null,
    val phone: String? = null,
    val photoUrl: String? = null
) {
    companion object {
        fun fromDocument(doc: DocumentSnapshot): Rebbe? {
            val data = doc.data ?: return null
            return Rebbe(
                id = doc.id,
                name = data["name"] as? String ?: "",
                title = data["title"] as? String ?: "",
                email = data["email"] as? String,
                phone = data["phone"] as? String,
                photoUrl = data["photoUrl"] as? String
            )
        }
    }
}

// MARK: - Shiur Collection Model
data class ShiurCollection(
    val id: String? = null,
    val name: String = "",
    val description: String = "",
    val isActive: Boolean = false,
    val shiurIds: List<String>? = null
) {
    companion object {
        fun fromDocument(doc: DocumentSnapshot): ShiurCollection? {
            val data = doc.data ?: return null
            return ShiurCollection(
                id = doc.id,
                name = data["name"] as? String ?: "",
                description = data["description"] as? String ?: "",
                isActive = data["isActive"] as? Boolean ?: false,
                shiurIds = (data["shiurIds"] as? List<*>)?.filterIsInstance<String>()
            )
        }
    }
}

// MARK: - User Profile
data class UserProfile(
    val id: String = "",
    val email: String = "",
    val firstName: String = "",
    val lastName: String = "",
    val isApproved: Boolean = false,
    val isAdmin: Boolean = false,
    val createdAt: Date? = null
) {
    val fullName: String get() = "$firstName $lastName"
    val displayName: String
        get() = if (firstName.isEmpty()) email.substringBefore("@") else firstName
}

// MARK: - Auth State
data class AuthState(
    val user: com.google.firebase.auth.FirebaseUser? = null,
    val isApproved: Boolean = false,
    val isAdmin: Boolean = false,
    val isLoading: Boolean = true,
    val userProfile: UserProfile? = null,
    val errorMessage: String? = null
)
