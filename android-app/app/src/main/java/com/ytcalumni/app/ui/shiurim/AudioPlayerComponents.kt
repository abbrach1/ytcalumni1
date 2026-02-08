package com.ytcalumni.app.ui.shiurim

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import com.ytcalumni.app.managers.AudioPlayerManager
import com.ytcalumni.app.ui.theme.*

object AudioPlayerComponents {

    @Composable
    fun MiniPlayer(
        audioPlayerManager: AudioPlayerManager,
        modifier: Modifier = Modifier
    ) {
        val playerState by audioPlayerManager.playerState.collectAsState()
        val shiur = playerState.currentShiur ?: return
        var showFullPlayer by remember { mutableStateOf(false) }

        Column(
            modifier = modifier
                .fillMaxWidth()
                .background(Navy)
                .clickable { showFullPlayer = true }
        ) {
            // Progress bar
            val progress = if (playerState.duration > 0) {
                playerState.currentTime.toFloat() / playerState.duration.toFloat()
            } else 0f

            LinearProgressIndicator(
                progress = { progress },
                modifier = Modifier
                    .fillMaxWidth()
                    .height(3.dp),
                color = Gold,
                trackColor = Navy.copy(alpha = 0.3f)
            )

            // Player content
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp, vertical = 12.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                // Info
                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        shiur.title,
                        color = Cream,
                        fontWeight = FontWeight.SemiBold,
                        fontSize = 14.sp,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis
                    )
                    Text(
                        shiur.rebbe,
                        color = Cream.copy(alpha = 0.7f),
                        fontSize = 12.sp
                    )
                }

                // Time
                Text(
                    audioPlayerManager.formatTime(playerState.currentTime),
                    color = Cream.copy(alpha = 0.7f),
                    fontSize = 12.sp
                )

                // Controls
                IconButton(onClick = { audioPlayerManager.skipBackward() }, modifier = Modifier.size(32.dp)) {
                    Icon(Icons.Filled.Replay, "Skip back 15s", tint = Cream, modifier = Modifier.size(20.dp))
                }

                IconButton(
                    onClick = { audioPlayerManager.togglePlayPause() },
                    modifier = Modifier
                        .size(40.dp)
                        .background(Gold, CircleShape)
                ) {
                    Icon(
                        if (playerState.isPlaying) Icons.Filled.Pause else Icons.Filled.PlayArrow,
                        "Play/Pause",
                        tint = Navy,
                        modifier = Modifier.size(24.dp)
                    )
                }

                IconButton(onClick = { audioPlayerManager.skipForward() }, modifier = Modifier.size(32.dp)) {
                    Icon(Icons.Filled.Forward30, "Skip forward 15s", tint = Cream, modifier = Modifier.size(20.dp))
                }

                IconButton(onClick = { audioPlayerManager.stop() }, modifier = Modifier.size(24.dp)) {
                    Icon(Icons.Filled.Close, "Stop", tint = Cream.copy(alpha = 0.7f), modifier = Modifier.size(16.dp))
                }
            }
        }

        if (showFullPlayer) {
            FullPlayerDialog(
                audioPlayerManager = audioPlayerManager,
                onDismiss = { showFullPlayer = false }
            )
        }
    }

    @Composable
    fun FullPlayerDialog(
        audioPlayerManager: AudioPlayerManager,
        onDismiss: () -> Unit
    ) {
        val playerState by audioPlayerManager.playerState.collectAsState()
        val shiur = playerState.currentShiur ?: return

        Dialog(
            onDismissRequest = onDismiss,
            properties = DialogProperties(usePlatformDefaultWidth = false)
        ) {
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .background(Cream)
                    .padding(24.dp),
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                // Top bar
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween
                ) {
                    IconButton(onClick = onDismiss) {
                        Icon(Icons.Filled.ExpandMore, "Minimize", tint = Navy)
                    }
                    IconButton(onClick = {
                        audioPlayerManager.stop()
                        onDismiss()
                    }) {
                        Icon(Icons.Filled.Close, "Stop & Close", tint = Navy.copy(alpha = 0.5f))
                    }
                }

                Spacer(modifier = Modifier.weight(1f))

                // Album art placeholder
                Box(
                    modifier = Modifier
                        .size(200.dp)
                        .background(Navy.copy(alpha = 0.1f), CircleShape),
                    contentAlignment = Alignment.Center
                ) {
                    Icon(
                        Icons.Filled.Headphones,
                        null,
                        tint = Navy.copy(alpha = 0.3f),
                        modifier = Modifier.size(80.dp)
                    )
                }

                Spacer(modifier = Modifier.height(32.dp))

                // Shiur info
                Text(
                    shiur.title,
                    fontWeight = FontWeight.SemiBold,
                    fontSize = 20.sp,
                    color = Navy,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis
                )
                Spacer(modifier = Modifier.height(8.dp))
                Text(shiur.rebbe, fontSize = 16.sp, color = Navy.copy(alpha = 0.7f))
                Spacer(modifier = Modifier.height(4.dp))
                Text(shiur.shortDate, fontSize = 12.sp, color = Navy.copy(alpha = 0.5f))

                Spacer(modifier = Modifier.height(32.dp))

                // Progress slider
                Column(modifier = Modifier.fillMaxWidth()) {
                    Slider(
                        value = playerState.currentTime.toFloat(),
                        onValueChange = { audioPlayerManager.seekTo(it.toLong()) },
                        valueRange = 0f..playerState.duration.toFloat().coerceAtLeast(1f),
                        colors = SliderDefaults.colors(
                            thumbColor = Gold,
                            activeTrackColor = Gold,
                            inactiveTrackColor = Navy.copy(alpha = 0.2f)
                        )
                    )
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween
                    ) {
                        Text(
                            audioPlayerManager.formatTime(playerState.currentTime),
                            fontSize = 12.sp,
                            color = Navy.copy(alpha = 0.6f)
                        )
                        Text(
                            audioPlayerManager.formatTime(playerState.duration),
                            fontSize = 12.sp,
                            color = Navy.copy(alpha = 0.6f)
                        )
                    }
                }

                Spacer(modifier = Modifier.height(24.dp))

                // Main controls
                Row(
                    horizontalArrangement = Arrangement.spacedBy(40.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    IconButton(onClick = { audioPlayerManager.skipBackward() }, modifier = Modifier.size(48.dp)) {
                        Icon(Icons.Filled.Replay, "Back 15s", tint = Navy, modifier = Modifier.size(36.dp))
                    }

                    IconButton(
                        onClick = { audioPlayerManager.togglePlayPause() },
                        modifier = Modifier
                            .size(72.dp)
                            .background(Navy, CircleShape)
                    ) {
                        Icon(
                            if (playerState.isPlaying) Icons.Filled.Pause else Icons.Filled.PlayArrow,
                            "Play/Pause",
                            tint = Cream,
                            modifier = Modifier.size(40.dp)
                        )
                    }

                    IconButton(onClick = { audioPlayerManager.skipForward() }, modifier = Modifier.size(48.dp)) {
                        Icon(Icons.Filled.Forward30, "Forward 15s", tint = Navy, modifier = Modifier.size(36.dp))
                    }
                }

                Spacer(modifier = Modifier.height(24.dp))

                // Speed and volume
                Row(
                    horizontalArrangement = Arrangement.spacedBy(24.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    // Speed selector
                    var showSpeedMenu by remember { mutableStateOf(false) }
                    Box {
                        TextButton(onClick = { showSpeedMenu = true }) {
                            Icon(Icons.Filled.Speed, null, tint = Navy, modifier = Modifier.size(18.dp))
                            Spacer(modifier = Modifier.width(4.dp))
                            Text(
                                "${playerState.playbackSpeed}x",
                                color = Navy,
                                fontWeight = FontWeight.Medium
                            )
                        }
                        DropdownMenu(expanded = showSpeedMenu, onDismissRequest = { showSpeedMenu = false }) {
                            audioPlayerManager.speedOptions.forEach { speed ->
                                DropdownMenuItem(
                                    text = {
                                        Row {
                                            Text("${speed}x")
                                            if (playerState.playbackSpeed == speed) {
                                                Spacer(modifier = Modifier.width(8.dp))
                                                Icon(Icons.Filled.Check, null, modifier = Modifier.size(16.dp))
                                            }
                                        }
                                    },
                                    onClick = {
                                        audioPlayerManager.setSpeed(speed)
                                        showSpeedMenu = false
                                    }
                                )
                            }
                        }
                    }

                    // Volume
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        Icon(
                            if (playerState.volume == 0f) Icons.Filled.VolumeOff else Icons.Filled.VolumeUp,
                            null,
                            tint = Navy.copy(alpha = 0.6f),
                            modifier = Modifier.size(16.dp)
                        )
                        Slider(
                            value = playerState.volume,
                            onValueChange = { audioPlayerManager.setVolume(it) },
                            modifier = Modifier.width(100.dp),
                            colors = SliderDefaults.colors(
                                thumbColor = Gold,
                                activeTrackColor = Gold,
                                inactiveTrackColor = Navy.copy(alpha = 0.2f)
                            )
                        )
                    }
                }

                Spacer(modifier = Modifier.weight(1f))
            }
        }
    }
}
