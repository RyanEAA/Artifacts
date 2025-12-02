// src/firebaseConfig.js
import { initializeApp } from "firebase/app";
import { getAnalytics } from "firebase/analytics";
import { getAuth } from "firebase/auth";
import { getFirestore } from "firebase/firestore";
import { getStorage } from "firebase/storage";

const firebaseConfig = {
  apiKey: "AIzaSyDup-NKePjY9n5IRWTePbXnuHNeL5Xw4U8",
  authDomain: "artutorial-b7500.firebaseapp.com",
  projectId: "artutorial-b7500",
  storageBucket: "artutorial-b7500.firebasestorage.app",
  messagingSenderId: "929563070453",
  appId: "1:929563070453:web:70a17fe83ab27f57d01abc",
  measurementId: "G-2H6MNB2VDQ"
};

// Initialize Firebase
const app = initializeApp(firebaseConfig);
const analytics = getAnalytics(app);
export const auth = getAuth(app);
export const db = getFirestore(app);
export const storage = getStorage(app);
