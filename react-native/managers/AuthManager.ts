import {
  signInWithEmailAndPassword,
  createUserWithEmailAndPassword,
  signOut as firebaseSignOut,
  onAuthStateChanged,
  User,
} from 'firebase/auth';
import { doc, getDoc, setDoc, collection, query, where, getDocs } from 'firebase/firestore';
import { auth, db } from '../services/firebaseConfig';

export interface UserProfile {
  id: string;
  email: string;
  firstName: string;
  lastName: string;
  isApproved: boolean;
  isAdmin: boolean;
}

export interface AuthState {
  user: User | null;
  isApproved: boolean;
  isAdmin: boolean;
  isLoading: boolean;
  userProfile: UserProfile | null;
  errorMessage: string | null;
}

/** Check if user email is approved (matches web app logic) */
export async function checkUserApproval(email: string): Promise<{ isApproved: boolean; isAdmin: boolean }> {
  const normalizedEmail = email.toLowerCase();
  let approved = false;
  let admin = false;

  try {
    // 1. Check alumniDatabase collection (document ID = email)
    const alumniDoc = await getDoc(doc(db, 'alumniDatabase', normalizedEmail));
    if (alumniDoc.exists()) approved = true;

    // 2. Fallback: Check approvedEmails collection (document ID = email)
    if (!approved) {
      const approvedDoc = await getDoc(doc(db, 'approvedEmails', normalizedEmail));
      if (approvedDoc.exists()) approved = true;
    }

    // 3. Fallback: Query approvedEmails by email field
    if (!approved) {
      const q = query(collection(db, 'approvedEmails'), where('email', '==', normalizedEmail));
      const snapshot = await getDocs(q);
      if (!snapshot.empty) approved = true;
    }

    // 4. Check admin status (document ID = email)
    const adminDoc = await getDoc(doc(db, 'admins', normalizedEmail));
    if (adminDoc.exists()) admin = true;

    // 5. Fallback: Query admins by email field
    if (!admin) {
      const q = query(collection(db, 'admins'), where('email', '==', normalizedEmail));
      const snapshot = await getDocs(q);
      if (!snapshot.empty) admin = true;
    }
  } catch (error) {
    console.error('Error checking user approval:', error);
  }

  return { isApproved: approved, isAdmin: admin };
}

export async function signIn(email: string, password: string) {
  const result = await signInWithEmailAndPassword(auth, email, password);
  const approval = await checkUserApproval(email);
  return { user: result.user, ...approval };
}

export async function signUp(
  email: string,
  password: string,
  firstName: string,
  lastName: string
) {
  const result = await createUserWithEmailAndPassword(auth, email, password);
  const normalizedEmail = email.toLowerCase();
  const approval = await checkUserApproval(normalizedEmail);

  // Create access request record
  const fullName = `${firstName} ${lastName}`;
  await setDoc(doc(db, 'accessRequests', normalizedEmail), {
    email: normalizedEmail,
    firstName,
    lastName,
    fullName,
    requestedAt: new Date().toISOString(),
    status: approval.isApproved ? 'approved' : 'pending',
    autoApproved: approval.isApproved,
  });

  return { user: result.user, ...approval };
}

export async function signOutUser() {
  await firebaseSignOut(auth);
}

export function onAuthChange(callback: (user: User | null) => void) {
  return onAuthStateChanged(auth, callback);
}
