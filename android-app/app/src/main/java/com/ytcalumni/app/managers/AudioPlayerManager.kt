package com.ytcalumni.app.managers

import android.content.Context
import android.content.SharedPreferences
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import androidx.media3.common.MediaItem
import androidx.media3.common.Player
import androidx.media3.exoplayer.ExoPlayer
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FieldValue
import com.google.firebase.firestore.FirebaseFirestore
import com.ytcalumni.app.models.Shiur
import dagger.hilt.android.lifecycle.HiltViewModel
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.tasks.await
import javax.inject.Inject

data class PlayerState(
    val currentShiur: Shiur? = null,
    val isPlaying: Boolean = false,
    val currentTime: Long = 0L,
    val duration: Long = 0L,
    val isLoading: Boolean = false,
    val playbackSpeed: Float = 1.0f,
    val volume: Float = 1.0f,
    val error: String? = null
)

@HiltViewModel
class AudioPlayerManager @Inject constructor(
    @ApplicationContext private val context: Context
) : ViewModel() {

    private val _playerState = MutableStateFlow(PlayerState())
    val playerState: StateFlow<PlayerState> = _playerState.asStateFlow()

    private var player: ExoPlayer? = null
    private var progressJob: Job? = null
    private val playedShiurimIds = mutableSetOf<String>()
    private val prefs: SharedPreferences = context.getSharedPreferences("ytc_playback", Context.MODE_PRIVATE)
    private val db = FirebaseFirestore.getInstance()

    val speedOptions = listOf(0.75f, 1.0f, 1.25f, 1.5f, 1.75f, 2.0f)

    private fun getOrCreatePlayer(): ExoPlayer {
        return player ?: ExoPlayer.Builder(context).build().also { newPlayer ->
            player = newPlayer
            newPlayer.addListener(object : Player.Listener {
                override fun onPlaybackStateChanged(playbackState: Int) {
                    when (playbackState) {
                        Player.STATE_READY -> {
                            _playerState.value = _playerState.value.copy(
                                isLoading = false,
                                duration = newPlayer.duration.coerceAtLeast(0)
                            )
                            startProgressTracking()
                        }
                        Player.STATE_ENDED -> {
                            _playerState.value = _playerState.value.copy(
                                isPlaying = false,
                                currentTime = 0
                            )
                            clearPlaybackPosition()
                            stopProgressTracking()
                        }
                        Player.STATE_BUFFERING -> {
                            _playerState.value = _playerState.value.copy(isLoading = true)
                        }
                        else -> {}
                    }
                }

                override fun onIsPlayingChanged(isPlaying: Boolean) {
                    _playerState.value = _playerState.value.copy(isPlaying = isPlaying)
                    if (isPlaying) startProgressTracking() else stopProgressTracking()
                }
            })
        }
    }

    fun play(shiur: Shiur) {
        val audioUrlString = shiur.audioUrl ?: run {
            _playerState.value = _playerState.value.copy(error = "Invalid audio URL")
            return
        }

        stop()

        val processedUrl = processAudioUrl(audioUrlString)
        _playerState.value = _playerState.value.copy(
            currentShiur = shiur,
            isLoading = true,
            error = null,
            currentTime = 0,
            duration = 0
        )

        val exoPlayer = getOrCreatePlayer()
        val mediaItem = MediaItem.fromUri(processedUrl)
        exoPlayer.setMediaItem(mediaItem)
        exoPlayer.playbackParameters = exoPlayer.playbackParameters.withSpeed(_playerState.value.playbackSpeed)
        exoPlayer.volume = _playerState.value.volume
        exoPlayer.prepare()

        // Restore position then play
        viewModelScope.launch {
            val savedPosition = restorePlaybackPosition(shiur)
            if (savedPosition > 0) {
                exoPlayer.seekTo(savedPosition)
            }
            exoPlayer.play()

            // Track play count
            shiur.id?.let { id ->
                if (!playedShiurimIds.contains(id)) {
                    playedShiurimIds.add(id)
                    try {
                        com.ytcalumni.app.services.FirebaseService().incrementPlayCount(id)
                    } catch (_: Exception) { }
                }
            }
        }
    }

    fun play() {
        player?.play()
    }

    fun pause() {
        player?.pause()
    }

    fun togglePlayPause() {
        if (_playerState.value.isPlaying) pause() else play()
    }

    fun stop() {
        stopProgressTracking()
        player?.stop()
        player?.clearMediaItems()
        _playerState.value = PlayerState(
            playbackSpeed = _playerState.value.playbackSpeed,
            volume = _playerState.value.volume
        )
    }

    fun seekTo(timeMs: Long) {
        player?.seekTo(timeMs)
        _playerState.value = _playerState.value.copy(currentTime = timeMs)
    }

    fun skipForward(seconds: Long = 15) {
        val newTime = (_playerState.value.currentTime + seconds * 1000)
            .coerceAtMost(_playerState.value.duration)
        seekTo(newTime)
    }

    fun skipBackward(seconds: Long = 15) {
        val newTime = (_playerState.value.currentTime - seconds * 1000)
            .coerceAtLeast(0)
        seekTo(newTime)
    }

    fun setSpeed(speed: Float) {
        _playerState.value = _playerState.value.copy(playbackSpeed = speed)
        player?.playbackParameters = player?.playbackParameters?.withSpeed(speed) ?: return
    }

    fun setVolume(newVolume: Float) {
        _playerState.value = _playerState.value.copy(volume = newVolume)
        player?.volume = newVolume
    }

    // MARK: - Progress Tracking
    private fun startProgressTracking() {
        stopProgressTracking()
        progressJob = viewModelScope.launch {
            while (true) {
                delay(500)
                player?.let { p ->
                    val currentPos = p.currentPosition.coerceAtLeast(0)
                    _playerState.value = _playerState.value.copy(currentTime = currentPos)
                    savePlaybackPosition()
                }
            }
        }
    }

    private fun stopProgressTracking() {
        progressJob?.cancel()
        progressJob = null
    }

    // MARK: - Playback Position Persistence
    private fun savePlaybackPosition() {
        val shiur = _playerState.value.currentShiur ?: return
        val id = shiur.id ?: return
        val currentTime = _playerState.value.currentTime

        // Save locally
        prefs.edit().putLong("playback_position_$id", currentTime).apply()

        // Save to Firebase
        val userId = FirebaseAuth.getInstance().currentUser?.uid ?: return
        val docRef = db.collection("users").document(userId)
            .collection("preferences").document("playbackPositions")

        val now = System.currentTimeMillis().toDouble()
        docRef.get().addOnSuccessListener { snapshot ->
            if (snapshot.exists()) {
                docRef.update(
                    mapOf(
                        "positions.$id" to (currentTime / 1000.0),
                        "lastUpdated" to now,
                        "syncedAt" to now
                    )
                )
            } else {
                docRef.set(
                    mapOf(
                        "positions" to mapOf(id to (currentTime / 1000.0)),
                        "lastUpdated" to now,
                        "syncedAt" to now
                    )
                )
            }
        }
    }

    private suspend fun restorePlaybackPosition(shiur: Shiur): Long {
        val id = shiur.id ?: return 0L
        val localPosition = prefs.getLong("playback_position_$id", 0L)

        val userId = FirebaseAuth.getInstance().currentUser?.uid ?: return localPosition

        return try {
            val doc = db.collection("users").document(userId)
                .collection("preferences").document("playbackPositions")
                .get().await()

            val data = doc.data
            val positions = data?.get("positions") as? Map<*, *>
            val position = (positions?.get(id) as? Number)?.toDouble() ?: 0.0
            val positionMs = (position * 1000).toLong()

            if (positionMs > 0) positionMs else localPosition
        } catch (_: Exception) {
            localPosition
        }
    }

    private fun clearPlaybackPosition() {
        val shiur = _playerState.value.currentShiur ?: return
        val id = shiur.id ?: return

        prefs.edit().remove("playback_position_$id").apply()

        val userId = FirebaseAuth.getInstance().currentUser?.uid ?: return
        val docRef = db.collection("users").document(userId)
            .collection("preferences").document("playbackPositions")

        val now = System.currentTimeMillis().toDouble()
        docRef.update(
            mapOf(
                "positions.$id" to FieldValue.delete(),
                "lastUpdated" to now,
                "syncedAt" to now
            )
        )
    }

    fun getSavedPosition(shiurId: String): Long {
        return prefs.getLong("playback_position_$shiurId", 0L)
    }

    suspend fun fetchAllPlaybackPositions(): Map<String, Double> {
        val userId = FirebaseAuth.getInstance().currentUser?.uid ?: return emptyMap()

        return try {
            val doc = db.collection("users").document(userId)
                .collection("preferences").document("playbackPositions")
                .get().await()

            val data = doc.data
            val positions = data?.get("positions") as? Map<*, *> ?: return emptyMap()
            val result = mutableMapOf<String, Double>()

            for ((key, value) in positions) {
                val k = key as? String ?: continue
                val v = (value as? Number)?.toDouble() ?: continue
                result[k] = v
                prefs.edit().putLong("playback_position_$k", (v * 1000).toLong()).apply()
            }

            result
        } catch (_: Exception) {
            emptyMap()
        }
    }

    // MARK: - URL Processing
    private fun processAudioUrl(url: String): String {
        if (url.contains("drive.google.com")) {
            extractGoogleDriveFileId(url)?.let { fileId ->
                return "https://drive.google.com/uc?export=download&id=$fileId"
            }
        }
        return url
    }

    private fun extractGoogleDriveFileId(url: String): String? {
        val fileIdPattern = Regex("/file/d/([^/]+)")
        fileIdPattern.find(url)?.groupValues?.get(1)?.let { return it }

        val idPattern = Regex("[?&]id=([^&]+)")
        idPattern.find(url)?.groupValues?.get(1)?.let { return it }

        return null
    }

    // MARK: - Helper
    fun formatTime(timeMs: Long): String {
        if (timeMs < 0) return "0:00"
        val totalSeconds = timeMs / 1000
        val hours = totalSeconds / 3600
        val minutes = (totalSeconds % 3600) / 60
        val seconds = totalSeconds % 60

        return if (hours > 0) {
            String.format("%d:%02d:%02d", hours, minutes, seconds)
        } else {
            String.format("%d:%02d", minutes, seconds)
        }
    }

    override fun onCleared() {
        super.onCleared()
        stopProgressTracking()
        player?.release()
        player = null
    }
}
