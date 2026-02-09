package com.ytcalumni.app.ui.events

import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil.compose.AsyncImage
import com.ytcalumni.app.managers.AuthManager
import com.ytcalumni.app.models.Event
import com.ytcalumni.app.services.FirebaseService
import com.ytcalumni.app.ui.components.CardContainer
import com.ytcalumni.app.ui.components.CustomTextField
import com.ytcalumni.app.ui.components.PrimaryButton
import com.ytcalumni.app.ui.theme.*
import kotlinx.coroutines.launch
import java.util.Date

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun EventsScreen(authManager: AuthManager) {
    val firebaseService = remember { FirebaseService() }
    val authState by authManager.authState.collectAsState()
    var events by remember { mutableStateOf<List<Event>>(emptyList()) }
    var isLoading by remember { mutableStateOf(true) }

    val upcomingEvents = remember(events) { events.filter { !it.isPast } }
    val pastEvents = remember(events) { events.filter { it.isPast } }

    LaunchedEffect(Unit) {
        try { events = firebaseService.fetchEvents() } catch (_: Exception) {}
        isLoading = false
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(Cream)
            .verticalScroll(rememberScrollState())
    ) {
        // Header
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .background(Navy)
                .padding(vertical = 32.dp),
            contentAlignment = Alignment.Center
        ) {
            Text(
                "Yeshiva Simchos",
                fontFamily = FontFamily.Serif,
                fontWeight = FontWeight.Bold,
                fontSize = 28.sp,
                color = Cream
            )
        }

        Column(
            modifier = Modifier.padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(32.dp)
        ) {
            // Upcoming Events
            if (upcomingEvents.isNotEmpty()) {
                Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
                    Text("Upcoming", fontSize = 18.sp, fontWeight = FontWeight.SemiBold, color = Navy)
                    upcomingEvents.forEach { event ->
                        EventDetailCard(event)
                    }
                }
            } else if (!isLoading) {
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = 40.dp),
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    Icon(Icons.Filled.CalendarMonth, null, tint = Navy.copy(alpha = 0.3f), modifier = Modifier.size(40.dp))
                    Spacer(modifier = Modifier.height(12.dp))
                    Text("No upcoming simchos", fontWeight = FontWeight.Bold, color = Navy.copy(alpha = 0.6f))
                }
            }

            // Past Events
            if (pastEvents.isNotEmpty()) {
                Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
                    Text("Past", fontSize = 14.sp, fontWeight = FontWeight.SemiBold, color = Navy.copy(alpha = 0.7f))
                    // Use a static grid layout instead of LazyVerticalGrid (inside scrollable)
                    val pastDisplay = pastEvents.take(8)
                    for (row in pastDisplay.chunked(2)) {
                        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                            row.forEach { event ->
                                PastEventCard(event, modifier = Modifier.weight(1f))
                            }
                            if (row.size == 1) Spacer(modifier = Modifier.weight(1f))
                        }
                    }
                }
            }

            // Submit Simcha Section
            Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
                Text("Share Your Simcha", fontSize = 18.sp, fontWeight = FontWeight.SemiBold, color = Navy)
                SimchaSubmissionForm(userEmail = authState.user?.email ?: "unknown")
            }
        }
    }
}

@Composable
private fun EventDetailCard(event: Event) {
    CardContainer {
        Column {
            // Image or gradient header
            if (!event.imageUrl.isNullOrEmpty()) {
                AsyncImage(
                    model = event.imageUrl,
                    contentDescription = event.eventName,
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(160.dp)
                        .clip(RoundedCornerShape(topStart = 16.dp, topEnd = 16.dp)),
                    contentScale = ContentScale.Crop
                )
            } else {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(12.dp)
                        .background(Brush.horizontalGradient(listOf(Navy, Gold)))
                )
            }

            Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Row(horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                    // Date badge
                    Column(
                        modifier = Modifier
                            .width(56.dp)
                            .background(Navy, RoundedCornerShape(8.dp))
                            .padding(vertical = 8.dp),
                        horizontalAlignment = Alignment.CenterHorizontally
                    ) {
                        Text(event.monthAbbreviation, fontSize = 10.sp, fontWeight = FontWeight.Medium, color = Cream.copy(alpha = 0.8f))
                        Text(event.dayNumber, fontSize = 20.sp, fontWeight = FontWeight.Bold, color = Cream)
                    }

                    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                        Surface(color = Gold.copy(alpha = 0.15f), shape = RoundedCornerShape(4.dp)) {
                            Text(event.type, fontSize = 12.sp, fontWeight = FontWeight.Medium, color = Gold, modifier = Modifier.padding(horizontal = 8.dp, vertical = 2.dp))
                        }
                        Text(event.eventName, fontWeight = FontWeight.Bold, color = Navy)
                        Text(event.personFamily, fontSize = 14.sp, color = Navy.copy(alpha = 0.7f))
                    }
                }

                HorizontalDivider(color = Navy.copy(alpha = 0.1f))

                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
                        Icon(Icons.Filled.LocationOn, null, tint = Gold, modifier = Modifier.size(14.dp))
                        Text(event.location, fontSize = 14.sp, color = Navy.copy(alpha = 0.7f))
                    }
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
                        Icon(Icons.Filled.CalendarMonth, null, tint = Gold, modifier = Modifier.size(14.dp))
                        Text(event.formattedDate, fontSize = 14.sp, color = Navy.copy(alpha = 0.7f))
                    }
                    event.time?.let {
                        Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
                            Icon(Icons.Filled.Schedule, null, tint = Gold, modifier = Modifier.size(14.dp))
                            Text(it, fontSize = 14.sp, color = Navy.copy(alpha = 0.7f))
                        }
                    }
                }

                event.description?.takeIf { it.isNotEmpty() }?.let {
                    Text(it, fontSize = 14.sp, color = Navy.copy(alpha = 0.6f), maxLines = 2, overflow = TextOverflow.Ellipsis)
                }
            }
        }
    }
}

@Composable
private fun PastEventCard(event: Event, modifier: Modifier = Modifier) {
    Card(
        modifier = modifier,
        shape = RoundedCornerShape(10.dp),
        elevation = CardDefaults.cardElevation(defaultElevation = 2.dp),
        colors = CardDefaults.cardColors(containerColor = White)
    ) {
        Row(modifier = Modifier.padding(12.dp), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            Column(
                modifier = Modifier
                    .width(44.dp)
                    .background(Navy.copy(alpha = 0.1f), RoundedCornerShape(6.dp))
                    .padding(vertical = 6.dp),
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                Text(event.monthAbbreviation, fontSize = 8.sp, fontWeight = FontWeight.Medium, color = Navy.copy(alpha = 0.6f))
                Text(event.dayNumber, fontSize = 14.sp, fontWeight = FontWeight.Bold, color = Navy)
            }
            Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                Text(event.eventName, fontSize = 12.sp, fontWeight = FontWeight.Medium, color = Navy, maxLines = 1, overflow = TextOverflow.Ellipsis)
                Text(event.personFamily, fontSize = 10.sp, color = Navy.copy(alpha = 0.5f), maxLines = 1, overflow = TextOverflow.Ellipsis)
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun SimchaSubmissionForm(userEmail: String) {
    val firebaseService = remember { FirebaseService() }
    val coroutineScope = rememberCoroutineScope()

    var fullName by remember { mutableStateOf("") }
    var simchaType by remember { mutableStateOf("") }
    var date by remember { mutableStateOf(Date()) }
    var connection by remember { mutableStateOf("") }
    var message by remember { mutableStateOf("") }
    var isSubmitting by remember { mutableStateOf(false) }
    var showSuccess by remember { mutableStateOf(false) }
    var errorMessage by remember { mutableStateOf<String?>(null) }
    var showDatePicker by remember { mutableStateOf(false) }
    val datePickerState = rememberDatePickerState()

    CardContainer {
        Column(
            modifier = Modifier.padding(20.dp),
            verticalArrangement = Arrangement.spacedBy(20.dp)
        ) {
            Column {
                Text("Full Name", fontSize = 14.sp, fontWeight = FontWeight.Medium, color = Navy)
                Spacer(modifier = Modifier.height(6.dp))
                CustomTextField(value = fullName, onValueChange = { fullName = it }, placeholder = "Enter full name")
            }

            Column {
                Text("Type of Simcha", fontSize = 14.sp, fontWeight = FontWeight.Medium, color = Navy)
                Spacer(modifier = Modifier.height(6.dp))
                CustomTextField(value = simchaType, onValueChange = { simchaType = it }, placeholder = "Wedding, Bar Mitzvah, etc.")
            }

            Column {
                Text("Date", fontSize = 14.sp, fontWeight = FontWeight.Medium, color = Navy)
                Spacer(modifier = Modifier.height(6.dp))
                OutlinedButton(onClick = { showDatePicker = true }, modifier = Modifier.fillMaxWidth()) {
                    Icon(Icons.Filled.CalendarMonth, null)
                    Spacer(modifier = Modifier.width(8.dp))
                    Text(java.text.SimpleDateFormat("MMM d, yyyy", java.util.Locale.US).format(date))
                }
            }

            Column {
                Row {
                    Text("Connection to Yeshiva", fontSize = 14.sp, fontWeight = FontWeight.Medium, color = Navy)
                    Spacer(modifier = Modifier.width(4.dp))
                    Text("(Optional)", fontSize = 12.sp, color = Navy.copy(alpha = 0.5f))
                }
                Spacer(modifier = Modifier.height(6.dp))
                CustomTextField(value = connection, onValueChange = { connection = it }, placeholder = "Alumnus, Parent, etc.")
            }

            Column {
                Row {
                    Text("Additional Details", fontSize = 14.sp, fontWeight = FontWeight.Medium, color = Navy)
                    Spacer(modifier = Modifier.width(4.dp))
                    Text("(Optional)", fontSize = 12.sp, color = Navy.copy(alpha = 0.5f))
                }
                Spacer(modifier = Modifier.height(6.dp))
                CustomTextField(
                    value = message,
                    onValueChange = { message = it },
                    placeholder = "Any additional details...",
                    singleLine = false
                )
            }

            PrimaryButton(
                text = if (isSubmitting) "Submitting..." else "Submit Simcha",
                onClick = {
                    isSubmitting = true
                    coroutineScope.launch {
                        try {
                            firebaseService.submitSimcha(
                                fullName = fullName,
                                simchaType = simchaType,
                                date = date,
                                connection = connection.ifEmpty { null },
                                message = message.ifEmpty { null },
                                imageUrl = null,
                                submittedBy = userEmail
                            )
                            showSuccess = true
                            fullName = ""; simchaType = ""; connection = ""; message = ""
                        } catch (e: Exception) {
                            errorMessage = e.localizedMessage
                        }
                        isSubmitting = false
                    }
                },
                isLoading = isSubmitting,
                enabled = fullName.isNotBlank() && simchaType.isNotBlank()
            )
        }
    }

    if (showDatePicker) {
        DatePickerDialog(
            onDismissRequest = { showDatePicker = false },
            confirmButton = {
                TextButton(onClick = {
                    datePickerState.selectedDateMillis?.let { date = Date(it) }
                    showDatePicker = false
                }) { Text("OK") }
            },
            dismissButton = {
                TextButton(onClick = { showDatePicker = false }) { Text("Cancel") }
            }
        ) {
            DatePicker(state = datePickerState)
        }
    }

    if (showSuccess) {
        AlertDialog(
            onDismissRequest = { showSuccess = false },
            title = { Text("Simcha Submitted!") },
            text = { Text("Thank you! Your simcha has been submitted for review.") },
            confirmButton = {
                TextButton(onClick = { showSuccess = false }) { Text("OK") }
            }
        )
    }

    errorMessage?.let {
        AlertDialog(
            onDismissRequest = { errorMessage = null },
            title = { Text("Error") },
            text = { Text(it) },
            confirmButton = {
                TextButton(onClick = { errorMessage = null }) { Text("OK") }
            }
        )
    }
}
