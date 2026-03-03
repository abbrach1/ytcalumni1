import { initializeApp } from 'firebase/app';
import { initializeAuth, getReactNativePersistence } from 'firebase/auth';
import { getFirestore } from 'firebase/firestore';
import { getMessaging, isSupported } from 'firebase/messaging';
import AsyncStorage from '@react-native-async-storage/async-storage';

const firebaseConfig = {
  apiKey: 'AIzaSyB-j6Itt_DKVLOm5BGsuygVUD6YoPKQyS8',
  authDomain: 'toras-chaim-shiurim.firebaseapp.com',
  projectId: 'toras-chaim-shiurim',
  storageBucket: 'toras-chaim-shiurim.firebasestorage.app',
  messagingSenderId: '95643621522',
  appId: '1:95643621522:ios:a75e5f1bdfaba692986e4b',
};

const app = initializeApp(firebaseConfig);

export const auth = initializeAuth(app, {
  persistence: getReactNativePersistence(AsyncStorage),
});

export const db = getFirestore(app);

export default app;
