package com.ytcalumni.app.ui.navigation

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CalendarMonth
import androidx.compose.material.icons.filled.Headphones
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.People
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.navigation.NavGraph.Companion.findStartDestination
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import com.ytcalumni.app.managers.AudioPlayerManager
import com.ytcalumni.app.managers.AuthManager
import com.ytcalumni.app.ui.contacts.ContactsScreen
import com.ytcalumni.app.ui.events.EventsScreen
import com.ytcalumni.app.ui.home.HomeScreen
import com.ytcalumni.app.ui.shiurim.CollectionDetailScreen
import com.ytcalumni.app.ui.shiurim.AudioPlayerComponents
import com.ytcalumni.app.ui.shiurim.ShiurimScreen
import com.ytcalumni.app.ui.theme.Gold
import com.ytcalumni.app.ui.theme.Navy

sealed class Screen(val route: String, val title: String, val icon: ImageVector) {
    data object Home : Screen("home", "Home", Icons.Filled.Home)
    data object Shiurim : Screen("shiurim", "Shiurim", Icons.Filled.Headphones)
    data object Events : Screen("events", "Events", Icons.Filled.CalendarMonth)
    data object Contacts : Screen("contacts", "Contacts", Icons.Filled.People)
    data object CollectionDetail : Screen("collection/{collectionId}", "Collection", Icons.Filled.Headphones)
}

val bottomNavItems = listOf(Screen.Home, Screen.Shiurim, Screen.Events, Screen.Contacts)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MainScaffold(authManager: AuthManager) {
    val navController = rememberNavController()
    val audioPlayerManager: AudioPlayerManager = hiltViewModel()
    val playerState by audioPlayerManager.playerState.collectAsState()
    val navBackStackEntry by navController.currentBackStackEntryAsState()
    val currentRoute = navBackStackEntry?.destination?.route

    Scaffold(
        bottomBar = {
            NavigationBar(
                containerColor = MaterialTheme.colorScheme.surface,
            ) {
                bottomNavItems.forEach { screen ->
                    NavigationBarItem(
                        icon = { Icon(screen.icon, contentDescription = screen.title) },
                        label = { Text(screen.title) },
                        selected = currentRoute == screen.route,
                        onClick = {
                            navController.navigate(screen.route) {
                                popUpTo(navController.graph.findStartDestination().id) {
                                    saveState = true
                                }
                                launchSingleTop = true
                                restoreState = true
                            }
                        },
                        colors = NavigationBarItemDefaults.colors(
                            selectedIconColor = Gold,
                            selectedTextColor = Gold,
                            unselectedIconColor = Navy.copy(alpha = 0.5f),
                            unselectedTextColor = Navy.copy(alpha = 0.5f),
                            indicatorColor = Gold.copy(alpha = 0.1f)
                        )
                    )
                }
            }
        }
    ) { innerPadding ->
        Box(modifier = Modifier.fillMaxSize()) {
            NavHost(
                navController = navController,
                startDestination = Screen.Home.route,
                modifier = Modifier.padding(innerPadding)
            ) {
                composable(Screen.Home.route) {
                    HomeScreen(
                        authManager = authManager,
                        audioPlayerManager = audioPlayerManager,
                        onNavigateToShiurim = {
                            navController.navigate(Screen.Shiurim.route)
                        },
                        onNavigateToCollection = { collectionId ->
                            navController.navigate("collection/$collectionId")
                        }
                    )
                }
                composable(Screen.Shiurim.route) {
                    ShiurimScreen(audioPlayerManager = audioPlayerManager)
                }
                composable(Screen.Events.route) {
                    EventsScreen(authManager = authManager)
                }
                composable(Screen.Contacts.route) {
                    ContactsScreen(authManager = authManager)
                }
                composable("collection/{collectionId}") { backStackEntry ->
                    val collectionId = backStackEntry.arguments?.getString("collectionId") ?: ""
                    CollectionDetailScreen(
                        collectionId = collectionId,
                        audioPlayerManager = audioPlayerManager,
                        onBack = { navController.popBackStack() }
                    )
                }
            }

            // Mini Player overlay
            if (playerState.currentShiur != null) {
                AudioPlayerComponents.MiniPlayer(
                    audioPlayerManager = audioPlayerManager,
                    modifier = Modifier
                        .align(Alignment.BottomCenter)
                        .padding(bottom = innerPadding.calculateBottomPadding())
                )
            }
        }
    }
}
