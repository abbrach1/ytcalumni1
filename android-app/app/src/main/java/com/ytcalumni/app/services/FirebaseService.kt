package com.ytcalumni.app.services

import com.google.firebase.firestore.FieldValue
import com.google.firebase.firestore.FirebaseFirestore
import com.ytcalumni.app.models.*
import kotlinx.coroutines.tasks.await
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class FirebaseService @Inject constructor() {

    private val db = FirebaseFirestore.getInstance()

    // MARK: - Shiurim
    suspend fun fetchShiurim(): List<Shiur> {
        val snapshot = db.collection("shiurim")
            .orderBy("date", com.google.firebase.firestore.Query.Direction.DESCENDING)
            .get()
            .await()
        return snapshot.documents.mapNotNull { Shiur.fromDocument(it) }
    }

    suspend fun fetchMostRecentShiur(): Shiur? {
        val snapshot = db.collection("shiurim")
            .orderBy("date", com.google.firebase.firestore.Query.Direction.DESCENDING)
            .limit(1)
            .get()
            .await()
        return snapshot.documents.firstOrNull()?.let { Shiur.fromDocument(it) }
    }

    suspend fun incrementPlayCount(shiurId: String) {
        db.collection("shiurim").document(shiurId)
            .update("playCount", FieldValue.increment(1))
            .await()
    }

    suspend fun incrementDownloadCount(shiurId: String) {
        db.collection("shiurim").document(shiurId)
            .update("downloadCount", FieldValue.increment(1))
            .await()
    }

    // MARK: - Events
    suspend fun fetchEvents(): List<Event> {
        val snapshot = db.collection("events")
            .orderBy("date")
            .get()
            .await()
        return snapshot.documents.mapNotNull { Event.fromDocument(it) }
    }

    suspend fun fetchUpcomingEvents(limit: Int = 3): List<Event> {
        val today = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())
        val snapshot = db.collection("events")
            .whereGreaterThanOrEqualTo("date", today)
            .orderBy("date")
            .limit(limit.toLong())
            .get()
            .await()
        return snapshot.documents.mapNotNull { Event.fromDocument(it) }
    }

    // MARK: - Announcements
    suspend fun fetchAnnouncements(): List<Announcement> {
        val snapshot = db.collection("announcements")
            .whereEqualTo("enabled", true)
            .orderBy("date", com.google.firebase.firestore.Query.Direction.DESCENDING)
            .get()
            .await()
        return snapshot.documents.mapNotNull { Announcement.fromDocument(it) }
    }

    // MARK: - Carousel Images
    suspend fun fetchCarouselImages(): List<CarouselImage> {
        val snapshot = db.collection("carouselImages")
            .get()
            .await()
        return snapshot.documents
            .mapNotNull { CarouselImage.fromDocument(it) }
            .sortedBy { it.order }
    }

    // MARK: - Alumni Photos
    suspend fun fetchAlumniPhotos(): List<AlumniPhoto> {
        val snapshot = db.collection("alumniPhotos")
            .get()
            .await()
        return snapshot.documents
            .mapNotNull { AlumniPhoto.fromDocument(it) }
            .sortedBy { it.order }
    }

    // MARK: - Alumni Contacts
    suspend fun fetchApprovedAlumni(): List<AlumniContact> {
        val snapshot = db.collection("alumniContactSubmissions")
            .get()
            .await()
        return snapshot.documents
            .filter { (it.data?.get("status") as? String) == "approved" }
            .mapNotNull { AlumniContact.fromDocument(it) }
            .sortedBy { it.name.lowercase() }
    }

    // MARK: - Rebbeim
    suspend fun fetchRebbeim(): List<Rebbe> {
        val snapshot = db.collection("rebbeim")
            .get()
            .await()
        return snapshot.documents.mapNotNull { Rebbe.fromDocument(it) }
    }

    // MARK: - Collections
    suspend fun fetchActiveCollection(): ShiurCollection? {
        val snapshot = db.collection("shiurCollections")
            .get()
            .await()
        return snapshot.documents
            .mapNotNull { ShiurCollection.fromDocument(it) }
            .firstOrNull { it.isActive }
    }

    // MARK: - Featured Shiur
    suspend fun fetchFeaturedShiur(): Shiur? {
        val settingsDoc = db.collection("settings").document("featuredShiur")
            .get()
            .await()
        val data = settingsDoc.data ?: return null
        val enabled = data["enabled"] as? Boolean ?: return null
        if (!enabled) return null
        val shiurId = data["shiurId"] as? String ?: return null

        val shiurDoc = db.collection("shiurim").document(shiurId)
            .get()
            .await()
        return Shiur.fromDocument(shiurDoc)
    }

    // MARK: - Submissions
    suspend fun submitContactInfo(
        name: String,
        email: String?,
        phone: String?,
        location: String,
        submittedBy: String
    ) {
        val data = hashMapOf<String, Any?>(
            "name" to name,
            "email" to email,
            "phone" to phone,
            "location" to location,
            "submittedBy" to submittedBy,
            "submittedAt" to SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'", Locale.US).format(Date()),
            "status" to "pending"
        )
        db.collection("alumniContactSubmissions").add(data).await()
    }

    suspend fun updateContactInfo(
        documentId: String,
        name: String,
        phone: String?,
        location: String
    ) {
        val data = hashMapOf<String, Any?>(
            "name" to name,
            "phone" to phone,
            "location" to location
        )
        db.collection("alumniContactSubmissions").document(documentId)
            .update(data as Map<String, Any>)
            .await()
    }

    suspend fun submitSimcha(
        fullName: String,
        simchaType: String,
        date: Date,
        connection: String?,
        message: String?,
        imageUrl: String?,
        submittedBy: String
    ) {
        val dateFormatter = SimpleDateFormat("yyyy-MM-dd", Locale.US)
        val data = hashMapOf<String, Any?>(
            "fullName" to fullName,
            "simchaType" to simchaType,
            "date" to dateFormatter.format(date),
            "connection" to connection,
            "message" to message,
            "imageUrl" to imageUrl,
            "submittedBy" to submittedBy,
            "submittedAt" to SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'", Locale.US).format(Date()),
            "status" to "new"
        )
        db.collection("simchaSubmissions").add(data).await()
    }
}
