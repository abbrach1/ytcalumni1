package com.ytcalumni.app.ui.contacts

import android.content.Intent
import android.net.Uri
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.ytcalumni.app.managers.AuthManager
import com.ytcalumni.app.models.AlumniContact
import com.ytcalumni.app.services.FirebaseService
import com.ytcalumni.app.ui.components.*
import com.ytcalumni.app.ui.theme.*
import kotlinx.coroutines.launch

enum class ContactTab(val label: String) { REBBEIM("Rebbeim"), ALUMNI("Alumni") }

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ContactsScreen(authManager: AuthManager) {
    val firebaseService = remember { FirebaseService() }
    val authState by authManager.authState.collectAsState()
    var alumni by remember { mutableStateOf<List<AlumniContact>>(emptyList()) }
    var alumniSearchText by remember { mutableStateOf("") }
    var expandedAlumniId by remember { mutableStateOf<String?>(null) }
    var isLoading by remember { mutableStateOf(true) }
    var selectedTab by remember { mutableStateOf(ContactTab.ALUMNI) }
    var showEditSheet by remember { mutableStateOf(false) }

    val coroutineScope = rememberCoroutineScope()

    val currentUserEmail = authState.user?.email?.lowercase()
    val currentUserAlumniRecord = remember(alumni, currentUserEmail) {
        alumni.firstOrNull { it.email?.lowercase() == currentUserEmail }
    }

    val filteredAlumni = remember(alumni, alumniSearchText) {
        if (alumniSearchText.isEmpty()) alumni
        else {
            val q = alumniSearchText.lowercase()
            alumni.filter {
                it.name.lowercase().contains(q) ||
                        (it.email?.lowercase()?.contains(q) == true) ||
                        it.location.lowercase().contains(q)
            }
        }
    }

    LaunchedEffect(Unit) {
        try { alumni = firebaseService.fetchApprovedAlumni() } catch (_: Exception) {}
        isLoading = false
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(Cream)
            .verticalScroll(rememberScrollState())
    ) {
        // Header
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .background(Navy)
                .padding(vertical = 32.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Text(
                "Directory",
                fontFamily = FontFamily.Serif,
                fontWeight = FontWeight.Bold,
                fontSize = 28.sp,
                color = Cream
            )
            Spacer(modifier = Modifier.height(8.dp))
            Text(
                "Connect with Rebbeim and fellow alumni",
                fontSize = 14.sp,
                color = Cream.copy(alpha = 0.7f)
            )
        }

        Column(
            modifier = Modifier.padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(24.dp)
        ) {
            // Tab Selector
            Card(
                shape = RoundedCornerShape(12.dp),
                elevation = CardDefaults.cardElevation(defaultElevation = 2.dp),
                colors = CardDefaults.cardColors(containerColor = White)
            ) {
                Row(modifier = Modifier.padding(4.dp)) {
                    ContactTab.entries.forEach { tab ->
                        val isSelected = selectedTab == tab
                        TextButton(
                            onClick = { selectedTab = tab },
                            modifier = Modifier.weight(1f),
                            colors = ButtonDefaults.textButtonColors(
                                containerColor = if (isSelected) Navy else White.copy(alpha = 0f),
                                contentColor = if (isSelected) Cream else Navy.copy(alpha = 0.6f)
                            ),
                            shape = RoundedCornerShape(8.dp)
                        ) {
                            Text(tab.label, fontWeight = FontWeight.Medium)
                        }
                    }
                }
            }

            // Content
            if (selectedTab == ContactTab.REBBEIM) {
                // Coming Soon
                CardContainer {
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(32.dp),
                        horizontalAlignment = Alignment.CenterHorizontally
                    ) {
                        Icon(Icons.Filled.MenuBook, null, tint = Navy.copy(alpha = 0.3f), modifier = Modifier.size(48.dp))
                        Spacer(modifier = Modifier.height(16.dp))
                        Text("Rebbeim Directory Coming Soon", fontWeight = FontWeight.Bold, color = Navy)
                        Spacer(modifier = Modifier.height(8.dp))
                        Text(
                            "We are working on building the Rebbeim directory. Check back soon for contact information for all the Rebbeim.",
                            fontSize = 14.sp,
                            color = Navy.copy(alpha = 0.6f),
                            modifier = Modifier.padding(horizontal = 16.dp),
                            lineHeight = 20.sp
                        )
                    }
                }
            } else {
                // Alumni Section
                Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
                    // Search bar
                    OutlinedTextField(
                        value = alumniSearchText,
                        onValueChange = { alumniSearchText = it },
                        placeholder = { Text("Search by name, email, or location", fontSize = 14.sp) },
                        modifier = Modifier.fillMaxWidth(),
                        singleLine = true,
                        leadingIcon = { Icon(Icons.Filled.Search, null, tint = Navy.copy(alpha = 0.4f)) },
                        trailingIcon = {
                            if (alumniSearchText.isNotEmpty()) {
                                IconButton(onClick = { alumniSearchText = "" }) {
                                    Icon(Icons.Filled.Clear, null, tint = Navy.copy(alpha = 0.4f))
                                }
                            }
                        },
                        colors = OutlinedTextFieldDefaults.colors(
                            focusedBorderColor = Gold.copy(alpha = 0.3f),
                            unfocusedBorderColor = Gold.copy(alpha = 0.3f),
                            focusedContainerColor = White,
                            unfocusedContainerColor = White,
                            cursorColor = Navy,
                            focusedTextColor = Navy,
                            unfocusedTextColor = Navy
                        ),
                        shape = RoundedCornerShape(12.dp)
                    )

                    // Edit / Add button
                    if (currentUserAlumniRecord != null) {
                        Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.End) {
                            TextButton(onClick = { showEditSheet = true }) {
                                Icon(Icons.Filled.Edit, null, tint = Gold, modifier = Modifier.size(16.dp))
                                Spacer(modifier = Modifier.width(4.dp))
                                Text("Edit Your Info", color = Gold, fontWeight = FontWeight.Medium)
                            }
                        }
                    } else {
                        Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.End) {
                            TextButton(onClick = { /* scroll to form */ }) {
                                Icon(Icons.Filled.AddCircle, null, tint = Gold, modifier = Modifier.size(16.dp))
                                Spacer(modifier = Modifier.width(4.dp))
                                Text("Add Your Info", color = Gold, fontWeight = FontWeight.Medium)
                            }
                        }
                    }

                    if (filteredAlumni.isEmpty()) {
                        CardContainer {
                            Column(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(32.dp),
                                horizontalAlignment = Alignment.CenterHorizontally
                            ) {
                                Icon(
                                    if (alumniSearchText.isEmpty()) Icons.Filled.People else Icons.Filled.Search,
                                    null, tint = Navy.copy(alpha = 0.3f), modifier = Modifier.size(36.dp)
                                )
                                Spacer(modifier = Modifier.height(12.dp))
                                Text(
                                    if (alumniSearchText.isEmpty()) "No alumni listed yet" else "No results found",
                                    fontWeight = FontWeight.Bold, color = Navy
                                )
                                Spacer(modifier = Modifier.height(8.dp))
                                Text(
                                    if (alumniSearchText.isEmpty()) "Be the first! Add your contact info below."
                                    else "Try a different search term.",
                                    fontSize = 14.sp, color = Navy.copy(alpha = 0.6f)
                                )
                            }
                        }
                    } else {
                        filteredAlumni.forEach { alumnus ->
                            AlumniContactCard(
                                alumnus = alumnus,
                                isExpanded = expandedAlumniId == alumnus.id,
                                onTap = {
                                    expandedAlumniId = if (expandedAlumniId == alumnus.id) null else alumnus.id
                                }
                            )
                        }
                    }
                }
            }

            // Contact Form
            Column {
                // Header
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .background(
                            Brush.horizontalGradient(listOf(Navy, NavyLight)),
                            RoundedCornerShape(topStart = 16.dp, topEnd = 16.dp)
                        )
                        .padding(20.dp)
                ) {
                    Text("Add Your Contact Info", fontWeight = FontWeight.Bold, color = Cream)
                    Spacer(modifier = Modifier.height(4.dp))
                    Text(
                        "Submit your details to be listed in the alumni directory.",
                        fontSize = 12.sp,
                        color = Cream.copy(alpha = 0.7f)
                    )
                }

                // Form
                Card(
                    shape = RoundedCornerShape(bottomStart = 16.dp, bottomEnd = 16.dp),
                    elevation = CardDefaults.cardElevation(defaultElevation = 2.dp),
                    colors = CardDefaults.cardColors(containerColor = White)
                ) {
                    ContactInfoForm(userEmail = authState.user?.email ?: "unknown")
                }
            }
        }
    }

    // Edit sheet
    if (showEditSheet && currentUserAlumniRecord != null) {
        EditContactInfoSheet(
            alumnus = currentUserAlumniRecord,
            onDismiss = { showEditSheet = false },
            onSaved = {
                showEditSheet = false
                coroutineScope.launch {
                    try { alumni = firebaseService.fetchApprovedAlumni() } catch (_: Exception) {}
                }
            }
        )
    }
}

@Composable
private fun AlumniContactCard(
    alumnus: AlumniContact,
    isExpanded: Boolean,
    onTap: () -> Unit
) {
    val context = LocalContext.current
    val initials = remember(alumnus.name) {
        val parts = alumnus.name.split(" ")
        if (parts.size >= 2) "${parts[0].first()}${parts[1].first()}".uppercase()
        else alumnus.name.take(2).uppercase()
    }

    Card(
        shape = RoundedCornerShape(12.dp),
        elevation = CardDefaults.cardElevation(defaultElevation = 2.dp),
        colors = CardDefaults.cardColors(containerColor = White)
    ) {
        Column {
            // Header
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clickable { onTap() }
                    .padding(16.dp),
                horizontalArrangement = Arrangement.spacedBy(14.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Box(
                    modifier = Modifier
                        .size(44.dp)
                        .background(Navy.copy(alpha = 0.1f), CircleShape),
                    contentAlignment = Alignment.Center
                ) {
                    Text(initials, fontWeight = FontWeight.Bold, color = Navy)
                }

                Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                    Text(alumnus.name, fontWeight = FontWeight.Bold, color = Navy)
                    Text(alumnus.location, fontSize = 12.sp, color = Navy.copy(alpha = 0.6f))
                }

                Icon(
                    Icons.Filled.ExpandMore,
                    null,
                    tint = Navy.copy(alpha = 0.4f),
                    modifier = Modifier
                        .size(16.dp)
                        .rotate(if (isExpanded) 180f else 0f)
                )
            }

            // Expanded details
            AnimatedVisibility(visible = isExpanded) {
                Column {
                    HorizontalDivider(modifier = Modifier.padding(horizontal = 16.dp), color = Navy.copy(alpha = 0.1f))

                    Column(
                        modifier = Modifier.padding(horizontal = 16.dp, vertical = 12.dp),
                        verticalArrangement = Arrangement.spacedBy(12.dp)
                    ) {
                        alumnus.email?.takeIf { it.isNotEmpty() }?.let { email ->
                            Row(
                                modifier = Modifier.clickable {
                                    context.startActivity(Intent(Intent.ACTION_SENDTO, Uri.parse("mailto:$email")))
                                },
                                horizontalArrangement = Arrangement.spacedBy(10.dp),
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Icon(Icons.Filled.Email, null, tint = Gold, modifier = Modifier.size(18.dp))
                                Text(email, fontSize = 14.sp, color = Navy)
                            }
                        }

                        alumnus.phone?.takeIf { it.isNotEmpty() }?.let { phone ->
                            Row(
                                modifier = Modifier.clickable {
                                    val cleaned = phone.filter { it.isDigit() }
                                    context.startActivity(Intent(Intent.ACTION_DIAL, Uri.parse("tel:$cleaned")))
                                },
                                horizontalArrangement = Arrangement.spacedBy(10.dp),
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Icon(Icons.Filled.Phone, null, tint = Gold, modifier = Modifier.size(18.dp))
                                Text(phone, fontSize = 14.sp, color = Navy)
                            }
                        }

                        Row(horizontalArrangement = Arrangement.spacedBy(10.dp), verticalAlignment = Alignment.CenterVertically) {
                            Icon(Icons.Filled.LocationOn, null, tint = Gold, modifier = Modifier.size(18.dp))
                            Text(alumnus.location, fontSize = 14.sp, color = Navy)
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun ContactInfoForm(userEmail: String) {
    val firebaseService = remember { FirebaseService() }
    val coroutineScope = rememberCoroutineScope()

    var name by remember { mutableStateOf("") }
    var email by remember { mutableStateOf("") }
    var phone by remember { mutableStateOf("") }
    var locationType by remember { mutableStateOf<String?>(null) }
    var otherLocation by remember { mutableStateOf("") }
    var isSubmitting by remember { mutableStateOf(false) }
    var showSuccess by remember { mutableStateOf(false) }
    var errorMessage by remember { mutableStateOf<String?>(null) }
    var showLocationMenu by remember { mutableStateOf(false) }

    val locationOptions = listOf("Eretz Yisroel", "Chutz Laaretz", "Other")
    val locationValue = if (locationType == "Other") otherLocation else (locationType ?: "")
    val isFormValid = name.isNotBlank() && locationType != null && (locationType != "Other" || otherLocation.isNotBlank())

    Column(
        modifier = Modifier.padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(20.dp)
    ) {
        Column {
            RequiredLabel("Full Name")
            Spacer(modifier = Modifier.height(6.dp))
            CustomTextField(value = name, onValueChange = { name = it }, placeholder = "Enter your full name")
        }

        Column {
            Row {
                Text("Email", fontSize = 14.sp, fontWeight = FontWeight.Medium, color = Navy)
                Spacer(modifier = Modifier.width(4.dp))
                Text("(Optional)", fontSize = 12.sp, color = Navy.copy(alpha = 0.5f))
            }
            Spacer(modifier = Modifier.height(6.dp))
            CustomTextField(value = email, onValueChange = { email = it }, placeholder = "your.email@example.com")
        }

        Column {
            Row {
                Text("Phone Number", fontSize = 14.sp, fontWeight = FontWeight.Medium, color = Navy)
                Spacer(modifier = Modifier.width(4.dp))
                Text("(Optional)", fontSize = 12.sp, color = Navy.copy(alpha = 0.5f))
            }
            Spacer(modifier = Modifier.height(6.dp))
            CustomTextField(value = phone, onValueChange = { phone = it }, placeholder = "(555) 123-4567")
        }

        Column {
            RequiredLabel("Current Location")
            Spacer(modifier = Modifier.height(6.dp))
            Box {
                OutlinedButton(
                    onClick = { showLocationMenu = true },
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(10.dp),
                    colors = ButtonDefaults.outlinedButtonColors(contentColor = if (locationType == null) Navy.copy(alpha = 0.5f) else Navy),
                    border = BorderStroke(1.dp, Gold.copy(alpha = 0.3f))
                ) {
                    Text(locationType ?: "Select your location", modifier = Modifier.weight(1f))
                    Icon(Icons.Filled.ExpandMore, null)
                }
                DropdownMenu(expanded = showLocationMenu, onDismissRequest = { showLocationMenu = false }) {
                    locationOptions.forEach { option ->
                        DropdownMenuItem(
                            text = { Text(option) },
                            trailingIcon = { if (locationType == option) Icon(Icons.Filled.Check, null, modifier = Modifier.size(16.dp)) },
                            onClick = { locationType = option; showLocationMenu = false }
                        )
                    }
                }
            }
        }

        if (locationType == "Other") {
            Column {
                RequiredLabel("Please specify location")
                Spacer(modifier = Modifier.height(6.dp))
                CustomTextField(value = otherLocation, onValueChange = { otherLocation = it }, placeholder = "Enter your location")
            }
        }

        PrimaryButton(
            text = if (isSubmitting) "Submitting..." else "Submit My Info",
            onClick = {
                isSubmitting = true
                coroutineScope.launch {
                    try {
                        firebaseService.submitContactInfo(
                            name = name,
                            email = email.ifEmpty { null },
                            phone = phone.ifEmpty { null },
                            location = locationValue,
                            submittedBy = userEmail
                        )
                        showSuccess = true
                        name = ""; email = ""; phone = ""; locationType = null; otherLocation = ""
                    } catch (e: Exception) {
                        errorMessage = e.localizedMessage
                    }
                    isSubmitting = false
                }
            },
            isLoading = isSubmitting,
            enabled = isFormValid
        )
    }

    if (showSuccess) {
        AlertDialog(
            onDismissRequest = { showSuccess = false },
            title = { Text("Information Submitted") },
            text = { Text("Thank you! Your contact information has been submitted and will appear in the directory soon.") },
            confirmButton = { TextButton(onClick = { showSuccess = false }) { Text("OK") } }
        )
    }

    errorMessage?.let {
        AlertDialog(
            onDismissRequest = { errorMessage = null },
            title = { Text("Error") },
            text = { Text(it) },
            confirmButton = { TextButton(onClick = { errorMessage = null }) { Text("OK") } }
        )
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun EditContactInfoSheet(
    alumnus: AlumniContact,
    onDismiss: () -> Unit,
    onSaved: () -> Unit
) {
    val firebaseService = remember { FirebaseService() }
    val coroutineScope = rememberCoroutineScope()

    var name by remember { mutableStateOf(alumnus.name) }
    var phone by remember { mutableStateOf(alumnus.phone ?: "") }
    var location by remember { mutableStateOf(alumnus.location) }
    var isSaving by remember { mutableStateOf(false) }
    var errorMessage by remember { mutableStateOf<String?>(null) }

    ModalBottomSheet(onDismissRequest = onDismiss) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(20.dp),
            verticalArrangement = Arrangement.spacedBy(20.dp)
        ) {
            Text("Edit Your Info", fontWeight = FontWeight.Bold, fontSize = 18.sp, color = Navy)

            Column {
                Text("Full Name", fontSize = 14.sp, fontWeight = FontWeight.Medium, color = Navy)
                Spacer(modifier = Modifier.height(6.dp))
                CustomTextField(value = name, onValueChange = { name = it })
            }

            Column {
                Row {
                    Text("Email", fontSize = 14.sp, fontWeight = FontWeight.Medium, color = Navy)
                    Spacer(modifier = Modifier.width(4.dp))
                    Text("(cannot be changed)", fontSize = 12.sp, color = Navy.copy(alpha = 0.5f))
                }
                Spacer(modifier = Modifier.height(6.dp))
                Text(
                    alumnus.email ?: "",
                    fontSize = 14.sp,
                    color = Navy.copy(alpha = 0.6f),
                    modifier = Modifier
                        .fillMaxWidth()
                        .background(Cream, RoundedCornerShape(10.dp))
                        .padding(16.dp)
                )
            }

            Column {
                Text("Phone Number", fontSize = 14.sp, fontWeight = FontWeight.Medium, color = Navy)
                Spacer(modifier = Modifier.height(6.dp))
                CustomTextField(value = phone, onValueChange = { phone = it }, placeholder = "(555) 123-4567")
            }

            Column {
                Text("Location", fontSize = 14.sp, fontWeight = FontWeight.Medium, color = Navy)
                Spacer(modifier = Modifier.height(6.dp))
                CustomTextField(value = location, onValueChange = { location = it })
            }

            PrimaryButton(
                text = if (isSaving) "Saving..." else "Save Changes",
                onClick = {
                    val docId = alumnus.id ?: return@PrimaryButton
                    isSaving = true
                    coroutineScope.launch {
                        try {
                            firebaseService.updateContactInfo(docId, name, phone.ifEmpty { null }, location)
                            onSaved()
                        } catch (e: Exception) {
                            errorMessage = e.localizedMessage
                        }
                        isSaving = false
                    }
                },
                isLoading = isSaving,
                enabled = name.isNotBlank() && location.isNotBlank()
            )

            Spacer(modifier = Modifier.height(32.dp))
        }
    }

    errorMessage?.let {
        AlertDialog(
            onDismissRequest = { errorMessage = null },
            title = { Text("Error") },
            text = { Text(it) },
            confirmButton = { TextButton(onClick = { errorMessage = null }) { Text("OK") } }
        )
    }
}
