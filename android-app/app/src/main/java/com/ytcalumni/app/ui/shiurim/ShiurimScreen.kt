package com.ytcalumni.app.ui.shiurim

import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FieldValue
import com.google.firebase.firestore.FirebaseFirestore
import com.ytcalumni.app.managers.AudioPlayerManager
import com.ytcalumni.app.models.Shiur
import com.ytcalumni.app.services.FirebaseService
import com.ytcalumni.app.ui.components.CardContainer
import com.ytcalumni.app.ui.components.TagChip
import com.ytcalumni.app.ui.theme.*
import kotlinx.coroutines.launch
import kotlinx.coroutines.tasks.await

enum class SortOrder(val label: String) {
    DATE_DESC("Newest First"),
    DATE_ASC("Oldest First"),
    TITLE_AZ("Title A-Z"),
    REBBE_AZ("Rebbe A-Z")
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ShiurimScreen(audioPlayerManager: AudioPlayerManager) {
    val firebaseService = remember { FirebaseService() }
    val playerState by audioPlayerManager.playerState.collectAsState()

    var shiurim by remember { mutableStateOf<List<Shiur>>(emptyList()) }
    var isLoading by remember { mutableStateOf(true) }
    var searchText by remember { mutableStateOf("") }
    var selectedRebbeFilter by remember { mutableStateOf<String?>(null) }
    var selectedTagFilter by remember { mutableStateOf<String?>(null) }
    var selectedSeriesFilter by remember { mutableStateOf<String?>(null) }
    var showSavedOnly by remember { mutableStateOf(false) }
    var showInProgressOnly by remember { mutableStateOf(false) }
    var sortOrder by remember { mutableStateOf(SortOrder.DATE_DESC) }
    var showFilters by remember { mutableStateOf(false) }
    var savedShiurimIds by remember { mutableStateOf(setOf<String>()) }
    var playbackPositions by remember { mutableStateOf(mapOf<String, Double>()) }

    val coroutineScope = rememberCoroutineScope()

    val allRebbeim = remember(shiurim) { shiurim.map { it.rebbe }.distinct().sorted() }
    val allTags = remember(shiurim) { shiurim.flatMap { it.tags }.distinct().sorted() }
    val allSeries = remember(shiurim) { shiurim.mapNotNull { it.series }.distinct().sorted() }

    val filteredShiurim = remember(shiurim, searchText, selectedRebbeFilter, selectedTagFilter, selectedSeriesFilter, showSavedOnly, showInProgressOnly, sortOrder) {
        var result = shiurim
        if (searchText.isNotEmpty()) {
            val query = searchText.lowercase()
            result = result.filter {
                it.title.lowercase().contains(query) ||
                        it.rebbe.lowercase().contains(query) ||
                        it.tags.any { tag -> tag.lowercase().contains(query) } ||
                        (it.series?.lowercase()?.contains(query) == true)
            }
        }
        selectedRebbeFilter?.let { rebbe -> result = result.filter { it.rebbe == rebbe } }
        selectedTagFilter?.let { tag -> result = result.filter { it.tags.contains(tag) } }
        selectedSeriesFilter?.let { series -> result = result.filter { it.series == series } }
        if (showSavedOnly) result = result.filter { it.id != null && savedShiurimIds.contains(it.id) }
        if (showInProgressOnly) result = result.filter { it.id != null && (playbackPositions[it.id] ?: 0.0) > 0 }
        when (sortOrder) {
            SortOrder.DATE_DESC -> result.sortedByDescending { it.date }
            SortOrder.DATE_ASC -> result.sortedBy { it.date }
            SortOrder.TITLE_AZ -> result.sortedBy { it.title }
            SortOrder.REBBE_AZ -> result.sortedBy { it.rebbe }
        }
    }

    val hasActiveFilters = selectedRebbeFilter != null || selectedTagFilter != null || selectedSeriesFilter != null || showSavedOnly || showInProgressOnly
    val activeFilterCount = listOfNotNull(selectedRebbeFilter, selectedTagFilter, selectedSeriesFilter).size +
            (if (showSavedOnly) 1 else 0) + (if (showInProgressOnly) 1 else 0)

    fun clearFilters() {
        selectedRebbeFilter = null; selectedTagFilter = null; selectedSeriesFilter = null
        showSavedOnly = false; showInProgressOnly = false; searchText = ""
    }

    LaunchedEffect(Unit) {
        try {
            shiurim = firebaseService.fetchShiurim()
            // Load saved shiurim
            val userId = FirebaseAuth.getInstance().currentUser?.uid
            if (userId != null) {
                val doc = FirebaseFirestore.getInstance()
                    .collection("users").document(userId)
                    .collection("preferences").document("savedShiurim")
                    .get().await()
                val ids = (doc.data?.get("savedShiurIds") as? List<*>)?.filterIsInstance<String>()
                savedShiurimIds = ids?.toSet() ?: emptySet()

                // Load playback positions
                playbackPositions = audioPlayerManager.fetchAllPlaybackPositions()
            }
        } catch (e: Exception) { e.printStackTrace() }
        isLoading = false
    }

    Column(modifier = Modifier.fillMaxSize().background(Cream)) {
        // Header
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .background(Navy)
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            Text(
                "Shiurim",
                fontFamily = FontFamily.Serif,
                fontWeight = FontWeight.Bold,
                fontSize = 24.sp,
                color = Cream
            )

            // Search bar
            Row(horizontalArrangement = Arrangement.spacedBy(12.dp), verticalAlignment = Alignment.CenterVertically) {
                OutlinedTextField(
                    value = searchText,
                    onValueChange = { searchText = it },
                    placeholder = { Text("Search by title, rebbe, or topic...", color = Navy.copy(alpha = 0.4f), fontSize = 14.sp) },
                    modifier = Modifier.weight(1f).height(48.dp),
                    singleLine = true,
                    leadingIcon = { Icon(Icons.Filled.Search, null, tint = Navy.copy(alpha = 0.4f)) },
                    trailingIcon = {
                        if (searchText.isNotEmpty()) {
                            IconButton(onClick = { searchText = "" }) {
                                Icon(Icons.Filled.Clear, null, tint = Navy.copy(alpha = 0.4f))
                            }
                        }
                    },
                    colors = OutlinedTextFieldDefaults.colors(
                        focusedContainerColor = White,
                        unfocusedContainerColor = White,
                        focusedBorderColor = White,
                        unfocusedBorderColor = White,
                        cursorColor = Navy,
                        focusedTextColor = Navy,
                        unfocusedTextColor = Navy
                    ),
                    shape = RoundedCornerShape(12.dp)
                )

                // Filter button
                Box {
                    IconButton(
                        onClick = { showFilters = true },
                        modifier = Modifier
                            .size(48.dp)
                            .background(Cream.copy(alpha = 0.2f), RoundedCornerShape(10.dp))
                    ) {
                        Icon(Icons.Filled.Tune, "Filters", tint = Cream)
                    }
                    if (activeFilterCount > 0) {
                        Badge(
                            modifier = Modifier.align(Alignment.TopEnd).offset(x = 4.dp, y = (-4).dp),
                            containerColor = Gold,
                            contentColor = Navy
                        ) {
                            Text("$activeFilterCount", fontSize = 10.sp)
                        }
                    }
                }
            }

            // Quick filter chips
            LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                item {
                    FilterChip(
                        selected = showSavedOnly,
                        onClick = { showSavedOnly = !showSavedOnly; if (showSavedOnly) showInProgressOnly = false },
                        label = { Text("Saved", fontSize = 12.sp) },
                        leadingIcon = { Icon(Icons.Filled.Bookmark, null, modifier = Modifier.size(14.dp)) },
                        colors = FilterChipDefaults.filterChipColors(
                            selectedContainerColor = Gold,
                            selectedLabelColor = Navy,
                            containerColor = Cream.copy(alpha = 0.2f),
                            labelColor = Cream
                        )
                    )
                }
                item {
                    FilterChip(
                        selected = showInProgressOnly,
                        onClick = { showInProgressOnly = !showInProgressOnly; if (showInProgressOnly) showSavedOnly = false },
                        label = { Text("In Progress", fontSize = 12.sp) },
                        leadingIcon = { Icon(Icons.Filled.Schedule, null, modifier = Modifier.size(14.dp)) },
                        colors = FilterChipDefaults.filterChipColors(
                            selectedContainerColor = Gold,
                            selectedLabelColor = Navy,
                            containerColor = Cream.copy(alpha = 0.2f),
                            labelColor = Cream
                        )
                    )
                }
                item {
                    var showSortMenu by remember { mutableStateOf(false) }
                    Box {
                        FilterChip(
                            selected = false,
                            onClick = { showSortMenu = true },
                            label = { Text(sortOrder.label, fontSize = 12.sp) },
                            leadingIcon = { Icon(Icons.Filled.SwapVert, null, modifier = Modifier.size(14.dp)) },
                            colors = FilterChipDefaults.filterChipColors(
                                containerColor = Cream.copy(alpha = 0.2f),
                                labelColor = Cream
                            )
                        )
                        DropdownMenu(expanded = showSortMenu, onDismissRequest = { showSortMenu = false }) {
                            SortOrder.entries.forEach { order ->
                                DropdownMenuItem(
                                    text = { Text(order.label) },
                                    trailingIcon = { if (sortOrder == order) Icon(Icons.Filled.Check, null, modifier = Modifier.size(16.dp)) },
                                    onClick = { sortOrder = order; showSortMenu = false }
                                )
                            }
                        }
                    }
                }
                if (hasActiveFilters) {
                    item {
                        TextButton(onClick = ::clearFilters) {
                            Icon(Icons.Filled.Close, null, tint = Gold, modifier = Modifier.size(14.dp))
                            Spacer(modifier = Modifier.width(4.dp))
                            Text("Clear", color = Gold, fontSize = 12.sp)
                        }
                    }
                }
            }

            // Active filter tags
            if (hasActiveFilters) {
                LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    selectedRebbeFilter?.let { r ->
                        item { ActiveFilterTag(r) { selectedRebbeFilter = null } }
                    }
                    selectedTagFilter?.let { t ->
                        item { ActiveFilterTag(t) { selectedTagFilter = null } }
                    }
                    selectedSeriesFilter?.let { s ->
                        item { ActiveFilterTag(s) { selectedSeriesFilter = null } }
                    }
                }
            }
        }

        // Content
        if (isLoading) {
            Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                CircularProgressIndicator(color = Navy)
            }
        } else if (filteredShiurim.isEmpty()) {
            Box(modifier = Modifier.fillMaxSize().padding(32.dp), contentAlignment = Alignment.Center) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Icon(Icons.Filled.Headphones, null, tint = Navy.copy(alpha = 0.3f), modifier = Modifier.size(48.dp))
                    Spacer(modifier = Modifier.height(16.dp))
                    Text(
                        when {
                            showSavedOnly -> "No saved shiurim"
                            showInProgressOnly -> "No shiurim in progress"
                            else -> "No shiurim found"
                        },
                        fontWeight = FontWeight.Bold, color = Navy
                    )
                    Spacer(modifier = Modifier.height(8.dp))
                    TextButton(onClick = ::clearFilters) {
                        Text("Clear Filters", color = Navy)
                    }
                }
            }
        } else {
            LazyColumn(
                contentPadding = PaddingValues(16.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                items(filteredShiurim, key = { it.id ?: it.hashCode().toString() }) { shiur ->
                    ShiurRowCard(
                        shiur = shiur,
                        isSaved = savedShiurimIds.contains(shiur.id),
                        isCurrentlyPlaying = playerState.currentShiur?.id == shiur.id,
                        savedPosition = playbackPositions[shiur.id] ?: 0.0,
                        audioPlayerManager = audioPlayerManager,
                        onToggleSave = {
                            val id = shiur.id ?: return@ShiurRowCard
                            val userId = FirebaseAuth.getInstance().currentUser?.uid ?: return@ShiurRowCard
                            val docRef = FirebaseFirestore.getInstance()
                                .collection("users").document(userId)
                                .collection("preferences").document("savedShiurim")

                            savedShiurimIds = if (savedShiurimIds.contains(id)) {
                                docRef.update("savedShiurIds", FieldValue.arrayRemove(id))
                                savedShiurimIds - id
                            } else {
                                docRef.set(
                                    mapOf(
                                        "savedShiurIds" to FieldValue.arrayUnion(id),
                                        "lastUpdated" to FieldValue.serverTimestamp()
                                    ),
                                    com.google.firebase.firestore.SetOptions.merge()
                                )
                                savedShiurimIds + id
                            }
                        }
                    )
                }

                // Bottom padding for mini player
                if (playerState.currentShiur != null) {
                    item { Spacer(modifier = Modifier.height(80.dp)) }
                }
            }
        }
    }

    // Filters bottom sheet
    if (showFilters) {
        ModalBottomSheet(onDismissRequest = { showFilters = false }) {
            FiltersSheet(
                allRebbeim = allRebbeim,
                allTags = allTags,
                allSeries = allSeries,
                selectedRebbeFilter = selectedRebbeFilter,
                selectedTagFilter = selectedTagFilter,
                selectedSeriesFilter = selectedSeriesFilter,
                onRebbeSelected = { selectedRebbeFilter = it },
                onTagSelected = { selectedTagFilter = it },
                onSeriesSelected = { selectedSeriesFilter = it },
                onReset = { selectedRebbeFilter = null; selectedTagFilter = null; selectedSeriesFilter = null },
                onDone = { showFilters = false }
            )
        }
    }
}

@Composable
private fun ShiurRowCard(
    shiur: Shiur,
    isSaved: Boolean,
    isCurrentlyPlaying: Boolean,
    savedPosition: Double,
    audioPlayerManager: AudioPlayerManager,
    onToggleSave: () -> Unit
) {
    val playerState by audioPlayerManager.playerState.collectAsState()
    val context = LocalContext.current
    val coroutineScope = rememberCoroutineScope()
    val hasProgress = savedPosition > 0

    CardContainer {
        Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            // Header
            Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                Box(
                    modifier = Modifier
                        .size(44.dp)
                        .background(if (isCurrentlyPlaying) Gold else Navy.copy(alpha = 0.1f), CircleShape),
                    contentAlignment = Alignment.Center
                ) {
                    Icon(
                        if (isCurrentlyPlaying && playerState.isPlaying) Icons.Filled.GraphicEq else Icons.Filled.Headphones,
                        null,
                        tint = if (isCurrentlyPlaying) Navy else Navy.copy(alpha = 0.5f),
                        modifier = Modifier.size(22.dp)
                    )
                }

                Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    Text(shiur.title, fontWeight = FontWeight.SemiBold, fontSize = 14.sp, color = Navy, maxLines = 2)
                    Text(shiur.rebbe, fontSize = 12.sp, color = Navy.copy(alpha = 0.7f))
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        Text(shiur.shortDate, fontSize = 10.sp, color = Navy.copy(alpha = 0.5f))
                        shiur.series?.takeIf { it.isNotEmpty() }?.let {
                            Text("\u2022", color = Navy.copy(alpha = 0.3f), fontSize = 10.sp)
                            Text(it, fontSize = 10.sp, color = Gold)
                        }
                    }
                }

                IconButton(onClick = onToggleSave, modifier = Modifier.size(32.dp)) {
                    Icon(
                        if (isSaved) Icons.Filled.Bookmark else Icons.Filled.BookmarkBorder,
                        "Save",
                        tint = if (isSaved) Gold else Navy.copy(alpha = 0.3f)
                    )
                }
            }

            // Tags
            if (shiur.tags.isNotEmpty()) {
                LazyRow(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    items(shiur.tags) { tag ->
                        Surface(color = Navy.copy(alpha = 0.06f), shape = RoundedCornerShape(4.dp)) {
                            Text(tag, fontSize = 10.sp, color = Navy.copy(alpha = 0.6f), modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp))
                        }
                    }
                }
            }

            // Progress indicator
            if (hasProgress && !isCurrentlyPlaying) {
                Row(horizontalArrangement = Arrangement.spacedBy(6.dp), verticalAlignment = Alignment.CenterVertically) {
                    Icon(Icons.Filled.History, null, tint = Gold, modifier = Modifier.size(12.dp))
                    Text(
                        "Resume from ${audioPlayerManager.formatTime((savedPosition * 1000).toLong())}",
                        fontSize = 10.sp,
                        color = Navy.copy(alpha = 0.6f)
                    )
                }
            }

            // Action buttons
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                if (shiur.audioUrl != null) {
                    Button(
                        onClick = {
                            if (isCurrentlyPlaying) audioPlayerManager.togglePlayPause()
                            else coroutineScope.launch { audioPlayerManager.play(shiur) }
                        },
                        modifier = Modifier.weight(1f).height(40.dp),
                        colors = ButtonDefaults.buttonColors(
                            containerColor = if (isCurrentlyPlaying) Gold else Navy,
                            contentColor = if (isCurrentlyPlaying) Navy else Cream
                        ),
                        shape = RoundedCornerShape(8.dp),
                        contentPadding = PaddingValues(horizontal = 8.dp)
                    ) {
                        Icon(
                            if (isCurrentlyPlaying && playerState.isPlaying) Icons.Filled.Pause else Icons.Filled.PlayArrow,
                            null,
                            modifier = Modifier.size(16.dp)
                        )
                        Spacer(modifier = Modifier.width(6.dp))
                        Text(
                            when {
                                isCurrentlyPlaying && playerState.isPlaying -> "Pause"
                                hasProgress && !isCurrentlyPlaying -> "Resume"
                                else -> "Play"
                            },
                            fontSize = 12.sp,
                            fontWeight = FontWeight.SemiBold
                        )
                    }
                }

                if (!shiur.pdfUrl.isNullOrEmpty()) {
                    OutlinedButton(
                        onClick = {
                            val intent = Intent(Intent.ACTION_VIEW, Uri.parse(shiur.pdfUrl))
                            context.startActivity(intent)
                        },
                        shape = RoundedCornerShape(8.dp),
                        modifier = Modifier.height(40.dp),
                        contentPadding = PaddingValues(horizontal = 12.dp)
                    ) {
                        Icon(Icons.Filled.Description, null, modifier = Modifier.size(14.dp))
                        Spacer(modifier = Modifier.width(4.dp))
                        Text("PDF", fontSize = 12.sp)
                    }
                }
            }
        }
    }
}

@Composable
private fun ActiveFilterTag(title: String, onRemove: () -> Unit) {
    Surface(
        color = Gold.copy(alpha = 0.3f),
        shape = RoundedCornerShape(16.dp)
    ) {
        Row(
            modifier = Modifier.padding(horizontal = 10.dp, vertical = 6.dp),
            horizontalArrangement = Arrangement.spacedBy(4.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(title, fontSize = 12.sp, fontWeight = FontWeight.Medium, color = Navy)
            Icon(
                Icons.Filled.Close, null,
                tint = Navy,
                modifier = Modifier
                    .size(14.dp)
                    .clickable { onRemove() }
            )
        }
    }
}

@Composable
private fun FiltersSheet(
    allRebbeim: List<String>,
    allTags: List<String>,
    allSeries: List<String>,
    selectedRebbeFilter: String?,
    selectedTagFilter: String?,
    selectedSeriesFilter: String?,
    onRebbeSelected: (String?) -> Unit,
    onTagSelected: (String?) -> Unit,
    onSeriesSelected: (String?) -> Unit,
    onReset: () -> Unit,
    onDone: () -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .verticalScroll(rememberScrollState())
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(24.dp)
    ) {
        Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
            TextButton(onClick = onReset) { Text("Reset", color = MaterialTheme.colorScheme.error) }
            TextButton(onClick = onDone) { Text("Done", fontWeight = FontWeight.SemiBold, color = Navy) }
        }

        // Rebbe section
        Text("Rebbe", fontWeight = FontWeight.Bold, color = Navy)
        Column {
            FilterOption("All Rebbeim", selectedRebbeFilter == null) { onRebbeSelected(null) }
            allRebbeim.forEach { rebbe ->
                FilterOption(rebbe, selectedRebbeFilter == rebbe) { onRebbeSelected(rebbe) }
            }
        }

        HorizontalDivider()

        // Series section
        if (allSeries.isNotEmpty()) {
            Text("Series", fontWeight = FontWeight.Bold, color = Navy)
            Column {
                FilterOption("All Series", selectedSeriesFilter == null) { onSeriesSelected(null) }
                allSeries.forEach { series ->
                    FilterOption(series, selectedSeriesFilter == series) { onSeriesSelected(series) }
                }
            }
            HorizontalDivider()
        }

        // Tags section
        Text("Topics", fontWeight = FontWeight.Bold, color = Navy)
        Column {
            FilterOption("All Topics", selectedTagFilter == null) { onTagSelected(null) }
            allTags.forEach { tag ->
                FilterOption(tag, selectedTagFilter == tag) { onTagSelected(tag) }
            }
        }

        Spacer(modifier = Modifier.height(32.dp))
    }
}

@Composable
private fun FilterOption(title: String, isSelected: Boolean, onClick: () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable { onClick() }
            .padding(vertical = 8.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(title, fontSize = 14.sp, color = if (isSelected) Gold else Navy)
        if (isSelected) {
            Icon(Icons.Filled.Check, null, tint = Gold, modifier = Modifier.size(16.dp))
        }
    }
}
