package com.ytcalumni.app.ui.home

import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil.compose.AsyncImage
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FirebaseFirestore
import com.ytcalumni.app.managers.AudioPlayerManager
import com.ytcalumni.app.managers.AuthManager
import com.ytcalumni.app.models.*
import com.ytcalumni.app.services.FirebaseService
import com.ytcalumni.app.ui.components.CardContainer
import com.ytcalumni.app.ui.components.SectionHeader
import com.ytcalumni.app.ui.components.TagChip
import com.ytcalumni.app.ui.theme.*
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.tasks.await

@Composable
fun HomeScreen(
    authManager: AuthManager,
    audioPlayerManager: AudioPlayerManager,
    onNavigateToShiurim: () -> Unit,
    onNavigateToCollection: (String) -> Unit
) {
    val authState by authManager.authState.collectAsState()
    val playerState by audioPlayerManager.playerState.collectAsState()
    val firebaseService = remember { FirebaseService() }

    var carouselImages by remember { mutableStateOf<List<CarouselImage>>(emptyList()) }
    var announcements by remember { mutableStateOf<List<Announcement>>(emptyList()) }
    var mostRecentShiur by remember { mutableStateOf<Shiur?>(null) }
    var featuredShiur by remember { mutableStateOf<Shiur?>(null) }
    var alumniPhotos by remember { mutableStateOf<List<AlumniPhoto>>(emptyList()) }
    var activeCollection by remember { mutableStateOf<ShiurCollection?>(null) }
    var showAllAnnouncements by remember { mutableStateOf(false) }
    var playbackPositions by remember { mutableStateOf<Map<String, Double>>(emptyMap()) }
    var isLoading by remember { mutableStateOf(true) }

    val coroutineScope = rememberCoroutineScope()

    LaunchedEffect(Unit) {
        try {
            carouselImages = firebaseService.fetchCarouselImages()
            announcements = firebaseService.fetchAnnouncements()
            mostRecentShiur = firebaseService.fetchMostRecentShiur()
            featuredShiur = firebaseService.fetchFeaturedShiur()
            alumniPhotos = firebaseService.fetchAlumniPhotos()
            activeCollection = firebaseService.fetchActiveCollection()
            playbackPositions = audioPlayerManager.fetchAllPlaybackPositions()
        } catch (e: Exception) {
            e.printStackTrace()
        }
        isLoading = false
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(Cream)
            .verticalScroll(rememberScrollState())
    ) {
        // Header with Carousel
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(350.dp)
        ) {
            if (carouselImages.isNotEmpty()) {
                val pagerState = rememberPagerState(pageCount = { carouselImages.size })

                LaunchedEffect(pagerState) {
                    while (true) {
                        delay(4000)
                        val nextPage = (pagerState.currentPage + 1) % carouselImages.size
                        pagerState.animateScrollToPage(nextPage)
                    }
                }

                HorizontalPager(state = pagerState) { page ->
                    AsyncImage(
                        model = carouselImages[page].url,
                        contentDescription = carouselImages[page].caption,
                        modifier = Modifier.fillMaxSize(),
                        contentScale = ContentScale.Crop
                    )
                }
            } else {
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .background(
                            Brush.linearGradient(listOf(Navy, NavyLight))
                        )
                )
            }

            // Gradient overlay
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(
                        Brush.verticalGradient(
                            colors = listOf(
                                Color.Transparent,
                                Color.Transparent,
                                Navy.copy(alpha = 0.85f)
                            )
                        )
                    )
            )

            // Profile Menu
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = 48.dp, end = 16.dp),
                contentAlignment = Alignment.TopEnd
            ) {
                var showMenu by remember { mutableStateOf(false) }
                IconButton(onClick = { showMenu = true }) {
                    Icon(
                        Icons.Filled.AccountCircle,
                        contentDescription = "Profile",
                        tint = White,
                        modifier = Modifier.size(32.dp)
                    )
                }
                DropdownMenu(expanded = showMenu, onDismissRequest = { showMenu = false }) {
                    if (authState.isAdmin) {
                        DropdownMenuItem(
                            text = { Text("Admin Dashboard") },
                            leadingIcon = { Icon(Icons.Filled.Settings, null) },
                            onClick = { showMenu = false }
                        )
                    }
                    DropdownMenuItem(
                        text = { Text("Sign Out", color = MaterialTheme.colorScheme.error) },
                        leadingIcon = { Icon(Icons.Filled.Logout, null, tint = MaterialTheme.colorScheme.error) },
                        onClick = {
                            showMenu = false
                            authManager.signOut()
                        }
                    )
                }
            }

            // Title overlay
            Column(
                modifier = Modifier
                    .align(Alignment.BottomCenter)
                    .padding(bottom = 40.dp),
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                Box(
                    modifier = Modifier
                        .width(50.dp)
                        .height(3.dp)
                        .background(Gold)
                )
                Spacer(modifier = Modifier.height(12.dp))
                Text(
                    text = "Yeshiva Toras Chaim",
                    fontFamily = FontFamily.Serif,
                    fontWeight = FontWeight.Bold,
                    fontSize = 28.sp,
                    color = White
                )
                Spacer(modifier = Modifier.height(4.dp))
                Text(
                    text = "ALUMNI NETWORK",
                    fontSize = 13.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = Gold,
                    letterSpacing = 4.sp
                )
                Spacer(modifier = Modifier.height(12.dp))
                Box(
                    modifier = Modifier
                        .width(50.dp)
                        .height(3.dp)
                        .background(Gold)
                )
            }
        }

        // Main content
        Column(
            modifier = Modifier.padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(28.dp)
        ) {
            // Announcements
            if (announcements.isNotEmpty()) {
                Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
                    SectionHeader("Announcements", Icons.Filled.Campaign)

                    val displayAnnouncements = if (showAllAnnouncements) announcements else announcements.take(3)
                    displayAnnouncements.forEach { announcement ->
                        AnnouncementCard(announcement)
                    }

                    if (announcements.size > 3) {
                        TextButton(onClick = { showAllAnnouncements = !showAllAnnouncements }) {
                            Text(
                                if (showAllAnnouncements) "Show Less" else "Show All (${announcements.size})",
                                color = Gold,
                                fontWeight = FontWeight.Medium
                            )
                            Spacer(modifier = Modifier.width(4.dp))
                            Icon(
                                if (showAllAnnouncements) Icons.Filled.ExpandLess else Icons.Filled.ExpandMore,
                                contentDescription = null,
                                tint = Gold,
                                modifier = Modifier.size(16.dp)
                            )
                        }
                    }
                }
            }

            // Active Collection
            activeCollection?.let { collection ->
                Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
                    SectionHeader(collection.name, Icons.Filled.Folder)

                    CardContainer {
                        Row(
                            modifier = Modifier
                                .clickable { collection.id?.let { onNavigateToCollection(it) } }
                                .padding(20.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Column(modifier = Modifier.weight(1f)) {
                                Text(
                                    collection.description,
                                    color = Navy.copy(alpha = 0.8f),
                                    maxLines = 2,
                                    overflow = TextOverflow.Ellipsis
                                )
                                Spacer(modifier = Modifier.height(8.dp))
                                Text(
                                    "View Collection \u2192",
                                    color = Gold,
                                    fontWeight = FontWeight.SemiBold,
                                    fontSize = 14.sp
                                )
                            }
                            Icon(
                                Icons.Filled.ChevronRight,
                                contentDescription = null,
                                tint = Navy.copy(alpha = 0.4f)
                            )
                        }
                    }
                }
            }

            // Featured Shiur
            featuredShiur?.let { shiur ->
                ShiurSection(
                    shiur = shiur,
                    isFeatured = true,
                    audioPlayerManager = audioPlayerManager,
                    playerState = playerState,
                    savedPosition = playbackPositions[shiur.id] ?: 0.0,
                    onNavigateToShiurim = onNavigateToShiurim
                )
            }

            // Most Recent Shiur (if different from featured)
            mostRecentShiur?.let { shiur ->
                if (shiur.id != featuredShiur?.id) {
                    ShiurSection(
                        shiur = shiur,
                        isFeatured = false,
                        audioPlayerManager = audioPlayerManager,
                        playerState = playerState,
                        savedPosition = playbackPositions[shiur.id] ?: 0.0,
                        onNavigateToShiurim = onNavigateToShiurim
                    )
                }
            }

            // Alumni Spotlight
            if (alumniPhotos.isNotEmpty()) {
                Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
                    SectionHeader("Alumni Spotlight", Icons.Filled.People)

                    // 2x2 grid
                    val photos = alumniPhotos.take(4)
                    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                        for (row in photos.chunked(2)) {
                            Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                                row.forEach { photo ->
                                    AlumniPhotoCard(photo, modifier = Modifier.weight(1f))
                                }
                                if (row.size == 1) Spacer(modifier = Modifier.weight(1f))
                            }
                        }
                    }
                }
            }

            // Bottom padding for mini player
            if (playerState.currentShiur != null) {
                Spacer(modifier = Modifier.height(80.dp))
            }
        }
    }
}

@Composable
private fun ShiurSection(
    shiur: Shiur,
    isFeatured: Boolean,
    audioPlayerManager: AudioPlayerManager,
    playerState: com.ytcalumni.app.managers.PlayerState,
    savedPosition: Double,
    onNavigateToShiurim: () -> Unit
) {
    val coroutineScope = rememberCoroutineScope()

    Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
        SectionHeader(
            if (isFeatured) "Featured Shiur" else "Most Recent Shiur",
            Icons.Filled.Headphones
        )

        CardContainer {
            Column(modifier = Modifier.padding(20.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
                // Title and Rebbe
                Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    Text(shiur.title, fontWeight = FontWeight.Bold, color = Navy)
                    Text(shiur.rebbe, fontSize = 14.sp, color = Navy.copy(alpha = 0.7f))
                }

                // Date
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
                    Icon(Icons.Filled.CalendarMonth, null, tint = Gold, modifier = Modifier.size(14.dp))
                    Text(shiur.formattedDate, fontSize = 14.sp, color = Navy.copy(alpha = 0.7f))
                }

                // Tags
                if (shiur.tags.isNotEmpty()) {
                    Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        shiur.tags.forEach { tag -> TagChip(tag) }
                    }
                }

                // Saved position
                if (savedPosition > 0) {
                    Row(horizontalArrangement = Arrangement.spacedBy(6.dp), verticalAlignment = Alignment.CenterVertically) {
                        Icon(Icons.Filled.History, null, tint = Gold, modifier = Modifier.size(14.dp))
                        Text(
                            "Resume from ${audioPlayerManager.formatTime((savedPosition * 1000).toLong())}",
                            fontSize = 12.sp,
                            color = Navy.copy(alpha = 0.7f)
                        )
                    }
                }

                // Play button
                if (shiur.audioUrl != null) {
                    val isCurrentShiur = playerState.currentShiur?.id == shiur.id
                    Button(
                        onClick = {
                            if (isCurrentShiur) audioPlayerManager.togglePlayPause()
                            else coroutineScope.launch { audioPlayerManager.play(shiur) }
                        },
                        modifier = Modifier.fillMaxWidth(),
                        colors = ButtonDefaults.buttonColors(containerColor = Navy, contentColor = Cream),
                        shape = RoundedCornerShape(10.dp)
                    ) {
                        Icon(
                            if (isCurrentShiur && playerState.isPlaying) Icons.Filled.Pause else Icons.Filled.PlayArrow,
                            null,
                            modifier = Modifier.size(18.dp)
                        )
                        Spacer(modifier = Modifier.width(8.dp))
                        Text(
                            when {
                                isCurrentShiur && playerState.isPlaying -> "Pause"
                                savedPosition > 0 && !isCurrentShiur -> "Resume"
                                else -> "Play"
                            },
                            fontWeight = FontWeight.SemiBold
                        )
                    }
                }

                // Browse All
                Button(
                    onClick = onNavigateToShiurim,
                    modifier = Modifier.fillMaxWidth(),
                    colors = ButtonDefaults.buttonColors(containerColor = Navy, contentColor = Cream),
                    shape = RoundedCornerShape(10.dp)
                ) {
                    Text("Browse All Shiurim", fontWeight = FontWeight.SemiBold)
                    Spacer(modifier = Modifier.width(8.dp))
                    Icon(Icons.Filled.ChevronRight, null, modifier = Modifier.size(18.dp))
                }
            }
        }
    }
}

@Composable
private fun AnnouncementCard(announcement: Announcement) {
    CardContainer {
        Row(
            modifier = Modifier.padding(16.dp),
            horizontalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            Box(
                modifier = Modifier
                    .size(32.dp)
                    .background(Gold.copy(alpha = 0.15f), RoundedCornerShape(8.dp)),
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    if (announcement.isMazelTov) Icons.Filled.Celebration else Icons.Filled.Campaign,
                    null,
                    tint = Gold,
                    modifier = Modifier.size(18.dp)
                )
            }

            Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Text(announcement.title, fontWeight = FontWeight.SemiBold, fontSize = 14.sp, color = Navy)
                Text(
                    announcement.content,
                    fontSize = 12.sp,
                    color = Navy.copy(alpha = 0.7f),
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis
                )
            }
        }
    }
}

@Composable
private fun AlumniPhotoCard(photo: AlumniPhoto, modifier: Modifier = Modifier) {
    Card(
        modifier = modifier,
        shape = RoundedCornerShape(10.dp),
        elevation = CardDefaults.cardElevation(defaultElevation = 2.dp)
    ) {
        Column {
            AsyncImage(
                model = photo.url,
                contentDescription = photo.name,
                modifier = Modifier
                    .fillMaxWidth()
                    .height(90.dp),
                contentScale = ContentScale.Crop
            )

            val hasInfo = !photo.name.isNullOrEmpty() || !photo.year.isNullOrEmpty()
            if (hasInfo) {
                Column(modifier = Modifier.padding(8.dp)) {
                    photo.name?.takeIf { it.isNotEmpty() }?.let {
                        Text(it, fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = Navy, maxLines = 1)
                    }
                    photo.year?.takeIf { it.isNotEmpty() }?.let {
                        Text("Class of $it", fontSize = 10.sp, color = Gold)
                    }
                }
            }
        }
    }
}
