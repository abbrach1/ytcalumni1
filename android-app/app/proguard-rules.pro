# Firebase
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }

# Models
-keep class com.ytcalumni.app.models.** { *; }

# Kotlin serialization
-keepattributes *Annotation*
-keepclassmembers class ** {
    @com.google.firebase.firestore.PropertyName <methods>;
}
