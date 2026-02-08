package com.ytcalumni.app.ui.shiurim

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.ytcalumni.app.managers.AudioPlayerManager
import com.ytcalumni.app.models.Shiur
import com.ytcalumni.app.models.ShiurCollection
import com.ytcalumni.app.services.FirebaseService
import com.ytcalumni.app.ui.components.CardContainer
import com.ytcalumni.app.ui.components.TagChip
import com.ytcalumni.app.ui.theme.*
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CollectionDetailScreen(
    collectionId: String,
    audioPlayerManager: AudioPlayerManager,
    onBack: () -> Unit
) {
    val firebaseService = remember { FirebaseService() }
    val playerState by audioPlayerManager.playerState.collectAsState()

    var collection by remember { mutableStateOf<ShiurCollection?>(null) }
    var shiurim by remember { mutableStateOf<List<Shiur>>(emptyList()) }
    var isLoading by remember { mutableStateOf(true) }

    val coroutineScope = rememberCoroutineScope()

    LaunchedEffect(collectionId) {
        try {
            val allShiurim = firebaseService.fetchShiurim()
            // Find the collection
            val col = firebaseService.fetchActiveCollection()
            collection = col
            if (col?.shiurIds != null) {
                shiurim = allShiurim.filter { shiur ->
                    shiur.id != null && col.shiurIds.contains(shiur.id)
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
        isLoading = false
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(collection?.name ?: "Collection") },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.Filled.ArrowBack, "Back")
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = Navy,
                    titleContentColor = Cream,
                    navigationIconContentColor = Cream
                )
            )
        }
    ) { padding ->
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .background(Cream)
                .padding(padding)
        ) {
            // Header
            item {
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .background(Navy)
                        .padding(vertical = 40.dp, horizontal = 16.dp),
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    Icon(Icons.Filled.Folder, null, tint = Gold, modifier = Modifier.size(40.dp))
                    Spacer(modifier = Modifier.height(12.dp))
                    Text(
                        collection?.name ?: "",
                        fontFamily = FontFamily.Serif,
                        fontWeight = FontWeight.Bold,
                        fontSize = 28.sp,
                        color = Cream,
                        textAlign = TextAlign.Center
                    )
                    Spacer(modifier = Modifier.height(8.dp))
                    Text(
                        collection?.description ?: "",
                        fontSize = 14.sp,
                        color = Cream.copy(alpha = 0.8f),
                        textAlign = TextAlign.Center
                    )
                    Spacer(modifier = Modifier.height(12.dp))
                    Surface(
                        color = Gold.copy(alpha = 0.2f),
                        shape = RoundedCornerShape(12.dp)
                    ) {
                        Text(
                            "${shiurim.size} Shiurim",
                            fontSize = 12.sp,
                            fontWeight = FontWeight.Medium,
                            color = Gold,
                            modifier = Modifier.padding(horizontal = 12.dp, vertical = 4.dp)
                        )
                    }
                }
            }

            if (isLoading) {
                item {
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(60.dp),
                        contentAlignment = Alignment.Center
                    ) {
                        CircularProgressIndicator(color = Navy)
                    }
                }
            } else if (shiurim.isEmpty()) {
                item {
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(60.dp),
                        horizontalAlignment = Alignment.CenterHorizontally
                    ) {
                        Icon(Icons.Filled.Headphones, null, tint = Navy.copy(alpha = 0.3f), modifier = Modifier.size(40.dp))
                        Spacer(modifier = Modifier.height(16.dp))
                        Text("No shiurim in this collection", fontWeight = FontWeight.Bold, color = Navy.copy(alpha = 0.6f))
                    }
                }
            } else {
                items(shiurim, key = { it.id ?: it.hashCode().toString() }) { shiur ->
                    CollectionShiurRow(
                        shiur = shiur,
                        audioPlayerManager = audioPlayerManager,
                        isCurrentlyPlaying = playerState.currentShiur?.id == shiur.id
                    )
                }

                // Bottom padding for mini player
                if (playerState.currentShiur != null) {
                    item { Spacer(modifier = Modifier.height(80.dp)) }
                }
            }
        }
    }
}

@Composable
private fun CollectionShiurRow(
    shiur: Shiur,
    audioPlayerManager: AudioPlayerManager,
    isCurrentlyPlaying: Boolean
) {
    val playerState by audioPlayerManager.playerState.collectAsState()
    val coroutineScope = rememberCoroutineScope()

    CardContainer(modifier = Modifier.padding(horizontal = 16.dp, vertical = 6.dp)) {
        Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Row(horizontalArrangement = Arrangement.SpaceBetween, modifier = Modifier.fillMaxWidth()) {
                Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    Text(shiur.title, fontWeight = FontWeight.Bold, color = Navy)
                    Text(shiur.rebbe, fontSize = 14.sp, color = Navy.copy(alpha = 0.7f))
                    Text(shiur.shortDate, fontSize = 12.sp, color = Navy.copy(alpha = 0.5f))
                }

                if (isCurrentlyPlaying) {
                    Row(
                        horizontalArrangement = Arrangement.spacedBy(4.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Box(modifier = Modifier.size(6.dp).background(androidx.compose.ui.graphics.Color.Green, CircleShape))
                        Text("Playing", fontSize = 10.sp, color = Navy.copy(alpha = 0.6f))
                    }
                }
            }

            // Tags
            if (shiur.tags.isNotEmpty()) {
                Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    shiur.tags.forEach { tag ->
                        Surface(color = Navy.copy(alpha = 0.08f), shape = RoundedCornerShape(4.dp)) {
                            Text(tag, fontSize = 10.sp, color = Navy.copy(alpha = 0.7f), modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp))
                        }
                    }
                }
            }

            // Play button
            if (shiur.audioUrl != null) {
                Button(
                    onClick = {
                        if (isCurrentlyPlaying) audioPlayerManager.togglePlayPause()
                        else coroutineScope.launch { audioPlayerManager.play(shiur) }
                    },
                    colors = ButtonDefaults.buttonColors(
                        containerColor = if (isCurrentlyPlaying) Gold else Navy,
                        contentColor = if (isCurrentlyPlaying) Navy else Cream
                    ),
                    shape = RoundedCornerShape(8.dp)
                ) {
                    Icon(
                        if (isCurrentlyPlaying && playerState.isPlaying) Icons.Filled.Pause else Icons.Filled.PlayArrow,
                        null,
                        modifier = Modifier.size(16.dp)
                    )
                    Spacer(modifier = Modifier.width(6.dp))
                    Text(
                        if (isCurrentlyPlaying && playerState.isPlaying) "Pause" else "Play",
                        fontWeight = FontWeight.Medium,
                        fontSize = 14.sp
                    )
                }
            }
        }
    }
}
