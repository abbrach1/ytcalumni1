package com.ytcalumni.app.ui.auth

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Email
import androidx.compose.material.icons.filled.HelpOutline
import androidx.compose.material.icons.filled.Schedule
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.ytcalumni.app.managers.AuthManager
import com.ytcalumni.app.ui.components.PrimaryButton
import com.ytcalumni.app.ui.theme.*

@Composable
fun RequestAccessScreen(authManager: AuthManager) {
    var isRefreshing by remember { mutableStateOf(false) }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(Cream)
            .padding(24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Spacer(modifier = Modifier.weight(1f))

        // Icon
        Box(
            modifier = Modifier
                .size(120.dp)
                .background(Gold.copy(alpha = 0.15f), CircleShape),
            contentAlignment = Alignment.Center
        ) {
            Icon(
                imageVector = Icons.Filled.Schedule,
                contentDescription = null,
                modifier = Modifier.size(48.dp),
                tint = Gold
            )
        }

        Spacer(modifier = Modifier.height(32.dp))

        // Title and Description
        Text(
            text = "Access Pending",
            fontFamily = FontFamily.Serif,
            fontWeight = FontWeight.Bold,
            fontSize = 28.sp,
            color = Navy
        )

        Spacer(modifier = Modifier.height(12.dp))

        Text(
            text = "Your account has been created and is awaiting approval from an administrator.",
            fontSize = 16.sp,
            color = Navy.copy(alpha = 0.7f),
            textAlign = TextAlign.Center,
            modifier = Modifier.padding(horizontal = 32.dp)
        )

        Spacer(modifier = Modifier.height(32.dp))

        // Info Box
        Card(
            colors = CardDefaults.cardColors(containerColor = Navy.copy(alpha = 0.05f)),
            shape = RoundedCornerShape(16.dp),
            modifier = Modifier.fillMaxWidth()
        ) {
            Column(
                modifier = Modifier.padding(20.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    Icon(Icons.Filled.Email, contentDescription = null, tint = Gold)
                    Text(
                        "You will receive an email once your account is approved",
                        fontSize = 14.sp,
                        color = Navy.copy(alpha = 0.8f)
                    )
                }
                Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    Icon(Icons.Filled.HelpOutline, contentDescription = null, tint = Gold)
                    Text(
                        "Questions? Contact alumni@ytchaim.com",
                        fontSize = 14.sp,
                        color = Navy.copy(alpha = 0.8f)
                    )
                }
            }
        }

        Spacer(modifier = Modifier.weight(1f))

        // Actions
        PrimaryButton(
            text = if (isRefreshing) "Checking..." else "Check Status",
            onClick = {
                isRefreshing = true
                authManager.refreshUserStatus()
                isRefreshing = false
            },
            isLoading = isRefreshing
        )

        Spacer(modifier = Modifier.height(16.dp))

        TextButton(onClick = { authManager.signOut() }) {
            Text(
                "Sign Out",
                fontSize = 14.sp,
                fontWeight = FontWeight.Medium,
                color = Navy.copy(alpha = 0.7f)
            )
        }

        Spacer(modifier = Modifier.height(40.dp))
    }
}
