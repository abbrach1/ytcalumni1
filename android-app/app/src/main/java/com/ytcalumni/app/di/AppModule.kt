package com.ytcalumni.app.di

import com.ytcalumni.app.services.FirebaseService
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
object AppModule {

    @Provides
    @Singleton
    fun provideFirebaseService(): FirebaseService {
        return FirebaseService()
    }
}
