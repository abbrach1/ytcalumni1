package com.ytcalumni.app.ui.auth

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Visibility
import androidx.compose.material.icons.filled.VisibilityOff
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.ytcalumni.app.managers.AuthManager
import com.ytcalumni.app.ui.components.CustomTextField
import com.ytcalumni.app.ui.components.PrimaryButton
import com.ytcalumni.app.ui.components.RequiredLabel
import com.ytcalumni.app.ui.theme.*
import kotlinx.coroutines.launch

@Composable
fun LoginScreen(authManager: AuthManager) {
    var email by remember { mutableStateOf("") }
    var password by remember { mutableStateOf("") }
    var confirmPassword by remember { mutableStateOf("") }
    var firstName by remember { mutableStateOf("") }
    var lastName by remember { mutableStateOf("") }
    var isSignUp by remember { mutableStateOf(false) }
    var isLoading by remember { mutableStateOf(false) }
    var showPassword by remember { mutableStateOf(false) }
    var showConfirmPassword by remember { mutableStateOf(false) }
    var errorMessage by remember { mutableStateOf<String?>(null) }
    val coroutineScope = rememberCoroutineScope()

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(Cream)
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 24.dp)
            .padding(bottom = 40.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Spacer(modifier = Modifier.height(60.dp))

        // Logo and Title
        Text(
            text = "Yeshiva Toras Chaim Alumni",
            fontFamily = FontFamily.Serif,
            fontWeight = FontWeight.Bold,
            fontSize = 28.sp,
            color = Navy,
            textAlign = TextAlign.Center
        )

        Spacer(modifier = Modifier.height(8.dp))

        Text(
            text = if (isSignUp) "Create your account" else "Sign in to access the alumni portal",
            fontSize = 14.sp,
            color = Navy.copy(alpha = 0.7f)
        )

        Spacer(modifier = Modifier.height(24.dp))

        // Sign Up Info Box
        if (isSignUp) {
            Card(
                colors = CardDefaults.cardColors(containerColor = Navy.copy(alpha = 0.05f)),
                shape = MaterialTheme.shapes.medium
            ) {
                Column(modifier = Modifier.padding(16.dp)) {
                    Text(
                        "How approval works:",
                        fontWeight = FontWeight.SemiBold,
                        fontSize = 14.sp,
                        color = Navy
                    )
                    Spacer(modifier = Modifier.height(8.dp))
                    BulletPoint("If your email is in our alumni database, you will be approved automatically")
                    BulletPoint("Otherwise, your request will be reviewed by an administrator")
                    BulletPoint("You will receive access once approved")
                }
            }
            Spacer(modifier = Modifier.height(16.dp))
        }

        // Form Fields
        Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
            if (isSignUp) {
                Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    Column(modifier = Modifier.weight(1f)) {
                        RequiredLabel("First Name")
                        Spacer(modifier = Modifier.height(6.dp))
                        CustomTextField(
                            value = firstName,
                            onValueChange = { firstName = it },
                            placeholder = "Moshe"
                        )
                    }
                    Column(modifier = Modifier.weight(1f)) {
                        RequiredLabel("Last Name")
                        Spacer(modifier = Modifier.height(6.dp))
                        CustomTextField(
                            value = lastName,
                            onValueChange = { lastName = it },
                            placeholder = "Cohen"
                        )
                    }
                }
            }

            Column {
                RequiredLabel("Email")
                Spacer(modifier = Modifier.height(6.dp))
                CustomTextField(
                    value = email,
                    onValueChange = { email = it },
                    placeholder = "email@example.com"
                )
            }

            Column {
                RequiredLabel("Password")
                Spacer(modifier = Modifier.height(6.dp))
                OutlinedTextField(
                    value = password,
                    onValueChange = { password = it },
                    placeholder = { Text("Password", color = Navy.copy(alpha = 0.5f)) },
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true,
                    visualTransformation = if (showPassword) VisualTransformation.None else PasswordVisualTransformation(),
                    keyboardOptions = KeyboardOptions(
                        keyboardType = KeyboardType.Password,
                        imeAction = ImeAction.Done
                    ),
                    trailingIcon = {
                        IconButton(onClick = { showPassword = !showPassword }) {
                            Icon(
                                if (showPassword) Icons.Filled.VisibilityOff else Icons.Filled.Visibility,
                                contentDescription = "Toggle password visibility",
                                tint = Navy.copy(alpha = 0.5f)
                            )
                        }
                    },
                    colors = OutlinedTextFieldDefaults.colors(
                        focusedBorderColor = Gold,
                        unfocusedBorderColor = Gold.copy(alpha = 0.3f),
                        focusedContainerColor = White,
                        unfocusedContainerColor = White,
                        cursorColor = Navy,
                        focusedTextColor = Navy,
                        unfocusedTextColor = Navy
                    ),
                    shape = MaterialTheme.shapes.medium
                )
            }

            if (isSignUp) {
                Column {
                    RequiredLabel("Confirm Password")
                    Spacer(modifier = Modifier.height(6.dp))
                    OutlinedTextField(
                        value = confirmPassword,
                        onValueChange = { confirmPassword = it },
                        placeholder = { Text("Confirm Password", color = Navy.copy(alpha = 0.5f)) },
                        modifier = Modifier.fillMaxWidth(),
                        singleLine = true,
                        visualTransformation = if (showConfirmPassword) VisualTransformation.None else PasswordVisualTransformation(),
                        trailingIcon = {
                            IconButton(onClick = { showConfirmPassword = !showConfirmPassword }) {
                                Icon(
                                    if (showConfirmPassword) Icons.Filled.VisibilityOff else Icons.Filled.Visibility,
                                    contentDescription = "Toggle password visibility",
                                    tint = Navy.copy(alpha = 0.5f)
                                )
                            }
                        },
                        colors = OutlinedTextFieldDefaults.colors(
                            focusedBorderColor = Gold,
                            unfocusedBorderColor = Gold.copy(alpha = 0.3f),
                            focusedContainerColor = White,
                            unfocusedContainerColor = White,
                            cursorColor = Navy,
                            focusedTextColor = Navy,
                            unfocusedTextColor = Navy
                        ),
                        shape = MaterialTheme.shapes.medium
                    )
                }
            }
        }

        Spacer(modifier = Modifier.height(24.dp))

        // Error message
        errorMessage?.let {
            Text(
                text = it,
                color = MaterialTheme.colorScheme.error,
                fontSize = 14.sp,
                modifier = Modifier.padding(bottom = 8.dp)
            )
        }

        // Submit Button
        PrimaryButton(
            text = if (isLoading) {
                if (isSignUp) "Creating Account..." else "Signing In..."
            } else {
                if (isSignUp) "Sign Up" else "Sign In"
            },
            onClick = {
                errorMessage = null
                if (isSignUp) {
                    if (firstName.isBlank() || lastName.isBlank()) {
                        errorMessage = "Please enter your first and last name."
                        return@PrimaryButton
                    }
                    if (password != confirmPassword) {
                        errorMessage = "Passwords don't match."
                        return@PrimaryButton
                    }
                }
                if (email.isBlank() || password.isBlank()) {
                    errorMessage = "Please fill in all required fields."
                    return@PrimaryButton
                }

                isLoading = true
                coroutineScope.launch {
                    val result = if (isSignUp) {
                        authManager.signUp(email, password, firstName.trim(), lastName.trim())
                    } else {
                        authManager.signIn(email, password)
                    }
                    result.onFailure { e ->
                        errorMessage = e.localizedMessage ?: "An error occurred"
                    }
                    isLoading = false
                }
            },
            isLoading = isLoading,
            enabled = !isLoading
        )

        Spacer(modifier = Modifier.height(16.dp))

        // Toggle Sign Up / Sign In
        TextButton(
            onClick = {
                isSignUp = !isSignUp
                errorMessage = null
            },
            enabled = !isLoading
        ) {
            Text(
                text = if (isSignUp) "Already have an account? Sign in" else "Don't have an account? Sign up",
                fontSize = 14.sp,
                color = Navy
            )
        }
    }
}

@Composable
private fun BulletPoint(text: String) {
    Row(
        horizontalArrangement = Arrangement.spacedBy(8.dp),
        modifier = Modifier.padding(vertical = 2.dp)
    ) {
        Text("\u2022", color = Navy.copy(alpha = 0.6f))
        Text(
            text = text,
            fontSize = 12.sp,
            color = Navy.copy(alpha = 0.8f)
        )
    }
}
