package com.ytcalumni.app.managers

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.auth.FirebaseUser
import com.google.firebase.firestore.FirebaseFirestore
import com.ytcalumni.app.models.AuthState
import com.ytcalumni.app.models.UserProfile
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.tasks.await
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import javax.inject.Inject

@HiltViewModel
class AuthManager @Inject constructor() : ViewModel() {

    private val auth = FirebaseAuth.getInstance()
    private val db = FirebaseFirestore.getInstance()

    private val _authState = MutableStateFlow(AuthState())
    val authState: StateFlow<AuthState> = _authState.asStateFlow()

    init {
        setupAuthListener()
    }

    private fun setupAuthListener() {
        auth.addAuthStateListener { firebaseAuth ->
            val user = firebaseAuth.currentUser
            viewModelScope.launch {
                if (user != null && user.email != null) {
                    _authState.value = _authState.value.copy(user = user, isLoading = true)
                    checkUserApproval(user.email!!)
                } else {
                    _authState.value = AuthState(
                        user = null,
                        isApproved = false,
                        isAdmin = false,
                        isLoading = false,
                        userProfile = null
                    )
                }
            }
        }
    }

    private suspend fun checkUserApproval(email: String) {
        val normalizedEmail = email.lowercase()
        var approved = false
        var admin = false

        try {
            // 1. Check alumniDatabase collection (document ID = email)
            val alumniDoc = db.collection("alumniDatabase")
                .document(normalizedEmail).get().await()
            if (alumniDoc.exists()) approved = true

            // 2. Fallback: approvedEmails collection (document ID = email)
            if (!approved) {
                val approvedDoc = db.collection("approvedEmails")
                    .document(normalizedEmail).get().await()
                if (approvedDoc.exists()) approved = true
            }

            // 3. Fallback: Query approvedEmails by email field
            if (!approved) {
                val approvedQuery = db.collection("approvedEmails")
                    .whereEqualTo("email", normalizedEmail).get().await()
                if (approvedQuery.documents.isNotEmpty()) approved = true
            }

            // 4. Check admin status
            val adminDoc = db.collection("admins")
                .document(normalizedEmail).get().await()
            if (adminDoc.exists()) admin = true

            // 5. Fallback: Query admins by email field
            if (!admin) {
                val adminQuery = db.collection("admins")
                    .whereEqualTo("email", normalizedEmail).get().await()
                if (adminQuery.documents.isNotEmpty()) admin = true
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }

        val userProfile = UserProfile(
            id = auth.currentUser?.uid ?: "",
            email = normalizedEmail,
            firstName = "",
            lastName = "",
            isApproved = approved,
            isAdmin = admin,
            createdAt = null
        )

        _authState.value = _authState.value.copy(
            isApproved = approved,
            isAdmin = admin,
            isLoading = false,
            userProfile = userProfile
        )
    }

    suspend fun signIn(email: String, password: String): Result<Pair<Boolean, Boolean>> {
        return try {
            _authState.value = _authState.value.copy(isLoading = true)
            val result = auth.signInWithEmailAndPassword(email, password).await()
            result.user?.email?.let { checkUserApproval(it) }
            Result.success(Pair(_authState.value.isApproved, _authState.value.isAdmin))
        } catch (e: Exception) {
            _authState.value = _authState.value.copy(isLoading = false, errorMessage = e.localizedMessage)
            Result.failure(e)
        }
    }

    suspend fun signUp(
        email: String,
        password: String,
        firstName: String,
        lastName: String
    ): Result<Pair<Boolean, Boolean>> {
        return try {
            _authState.value = _authState.value.copy(isLoading = true)
            val result = auth.createUserWithEmailAndPassword(email, password).await()
            val normalizedEmail = email.lowercase()

            checkUserApproval(normalizedEmail)

            // Create access request record
            val fullName = "$firstName $lastName"
            val accessRequestData = hashMapOf(
                "email" to normalizedEmail,
                "firstName" to firstName,
                "lastName" to lastName,
                "fullName" to fullName,
                "requestedAt" to SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'", Locale.US).format(Date()),
                "status" to if (_authState.value.isApproved) "approved" else "pending",
                "autoApproved" to _authState.value.isApproved
            )

            try {
                db.collection("accessRequests")
                    .document(normalizedEmail)
                    .set(accessRequestData)
                    .await()
            } catch (_: Exception) { }

            Result.success(Pair(_authState.value.isApproved, _authState.value.isAdmin))
        } catch (e: Exception) {
            _authState.value = _authState.value.copy(isLoading = false, errorMessage = e.localizedMessage)
            Result.failure(e)
        }
    }

    fun signOut() {
        auth.signOut()
        _authState.value = AuthState(isLoading = false)
    }

    fun refreshUserStatus() {
        viewModelScope.launch {
            auth.currentUser?.email?.let { checkUserApproval(it) }
        }
    }
}
