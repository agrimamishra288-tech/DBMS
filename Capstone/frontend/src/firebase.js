import { getApp, getApps, initializeApp } from 'firebase/app'
import { getAuth } from 'firebase/auth'

// Stray whitespace pasted into host env vars produces invalid iframe URLs
// (https://%20project.firebaseapp.com), so trim before handing values to Firebase.
const config = {
  apiKey: import.meta.env.VITE_FIREBASE_API_KEY?.trim(),
  authDomain: import.meta.env.VITE_FIREBASE_AUTH_DOMAIN?.trim(),
  projectId: import.meta.env.VITE_FIREBASE_PROJECT_ID?.trim(),
  appId: import.meta.env.VITE_FIREBASE_APP_ID?.trim(),
}

export const firebaseConfigured = Object.values(config).every(Boolean)
export const firebaseAuth = firebaseConfigured
  ? getAuth(getApps().length ? getApp() : initializeApp(config))
  : null
