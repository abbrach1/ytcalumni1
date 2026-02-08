package com.ytcalumni.app.ui.theme

import android.app.Activity
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.SideEffect
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.platform.LocalView
import androidx.core.view.WindowCompat

private val YTCColorScheme = lightColorScheme(
    primary = Navy,
    onPrimary = Cream,
    secondary = Gold,
    onSecondary = Navy,
    tertiary = NavyLight,
    background = Cream,
    onBackground = Navy,
    surface = White,
    onSurface = Navy,
    surfaceVariant = CreamDark,
    onSurfaceVariant = Navy,
    outline = Gold,
)

@Composable
fun YTCAlumniTheme(content: @Composable () -> Unit) {
    val view = LocalView.current
    if (!view.isInEditMode) {
        SideEffect {
            val window = (view.context as Activity).window
            window.statusBarColor = Navy.toArgb()
            WindowCompat.getInsetsController(window, view).isAppearanceLightStatusBars = false
        }
    }

    MaterialTheme(
        colorScheme = YTCColorScheme,
        typography = Typography,
        content = content
    )
}
