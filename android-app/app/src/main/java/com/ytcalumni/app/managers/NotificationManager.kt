package com.ytcalumni.app.managers

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.messaging.FirebaseMessaging
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import kotlinx.coroutines.tasks.await

object YTCNotificationManager {

    suspend fun requestPermission(activity: Activity): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (ContextCompat.checkSelfPermission(
                    activity,
                    Manifest.permission.POST_NOTIFICATIONS
                ) != PackageManager.PERMISSION_GRANTED
            ) {
                ActivityCompat.requestPermissions(
                    activity,
                    arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                    1001
                )
                return false
            }
        }
        subscribeToDefaultTopics()
        return true
    }

    fun subscribeToDefaultTopics() {
        subscribeToTopic("all_users")
        subscribeToTopic("announcements")
        subscribeToTopic("new_shiurim")
        subscribeToTopic("events")
    }

    fun subscribeToTopic(topic: String) {
        FirebaseMessaging.getInstance().subscribeToTopic(topic)
    }

    fun unsubscribeFromTopic(topic: String) {
        FirebaseMessaging.getInstance().unsubscribeFromTopic(topic)
    }

    suspend fun getToken(): String? {
        return try {
            FirebaseMessaging.getInstance().token.await()
        } catch (e: Exception) {
            null
        }
    }

    fun saveTokenToFirestore(token: String) {
        val userId = FirebaseAuth.getInstance().currentUser?.uid ?: return
        FirebaseFirestore.getInstance()
            .collection("users")
            .document(userId)
            .set(
                mapOf(
                    "fcmToken" to token,
                    "fcmTokenUpdatedAt" to com.google.firebase.firestore.FieldValue.serverTimestamp(),
                    "platform" to "android"
                ),
                com.google.firebase.firestore.SetOptions.merge()
            )
    }
}

class YTCFirebaseMessagingService : FirebaseMessagingService() {

    override fun onMessageReceived(remoteMessage: RemoteMessage) {
        super.onMessageReceived(remoteMessage)
        // Handle FCM messages - notification will be shown automatically
        // when app is in background. For foreground, Android handles it via
        // the notification channel created in YTCAlumniApp.
    }

    override fun onNewToken(token: String) {
        super.onNewToken(token)
        YTCNotificationManager.saveTokenToFirestore(token)
    }
}
