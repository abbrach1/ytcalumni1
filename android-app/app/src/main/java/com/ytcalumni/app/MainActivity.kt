package com.ytcalumni.app

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.hilt.navigation.compose.hiltViewModel
import com.ytcalumni.app.managers.AuthManager
import com.ytcalumni.app.ui.auth.LoginScreen
import com.ytcalumni.app.ui.auth.RequestAccessScreen
import com.ytcalumni.app.ui.components.LoadingScreen
import com.ytcalumni.app.ui.navigation.MainScaffold
import com.ytcalumni.app.ui.theme.YTCAlumniTheme
import dagger.hilt.android.AndroidEntryPoint

@AndroidEntryPoint
class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            YTCAlumniTheme {
                val authManager: AuthManager = hiltViewModel()
                val authState by authManager.authState.collectAsState()

                when {
                    authState.isLoading -> LoadingScreen()
                    authState.user == null -> LoginScreen(authManager = authManager)
                    !authState.isApproved -> RequestAccessScreen(authManager = authManager)
                    else -> MainScaffold(authManager = authManager)
                }
            }
        }
    }
}
