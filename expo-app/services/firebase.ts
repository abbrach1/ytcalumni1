import { initializeApp, getApps } from 'firebase/app';
import {
  getAuth,
  createUserWithEmailAndPassword,
  signInWithEmailAndPassword,
  signOut as firebaseSignOut,
  onAuthStateChanged,
  User,
  updateProfile,
} from 'firebase/auth';
import {
  getFirestore,
  collection,
  doc,
  getDoc,
  getDocs,
  query,
  where,
  orderBy,
  limit,
  updateDoc,
  increment,
  addDoc,
  serverTimestamp,
  DocumentSnapshot,
} from 'firebase/firestore';

// Firebase config from GoogleService-Info.plist
const firebaseConfig = {
  apiKey: 'AIzaSyB-j6Itt_DKVLOm5BGsuygVUD6YoPKQyS8',
  authDomain: 'toras-chaim-shiurim.firebaseapp.com',
  projectId: 'toras-chaim-shiurim',
  storageBucket: 'toras-chaim-shiurim.firebasestorage.app',
  messagingSenderId: '95643621522',
  appId: '1:95643621522:ios:a75e5f1bdfaba692986e4b',
};

// Initialize Firebase (avoid re-initializing)
const app = getApps().length === 0 ? initializeApp(firebaseConfig) : getApps()[0];
export const auth = getAuth(app);
export const db = getFirestore(app);

// ─── Helpers ────────────────────────────────────────────────────────────────

function docToShiur(d: DocumentSnapshot) {
  if (!d.exists()) return null;
  const data = d.data()!;
  return {
    id: d.id,
    title: data.title ?? '',
    rebbe: data.rebbe ?? '',
    date: data.date ?? '',
    tags: data.tags ?? [],
    audioUrl: data.audioUrl,
    pdfUrl: data.pdfUrl,
    description: data.description,
    playCount: data.playCount,
    downloadCount: data.downloadCount,
    series: data.series,
  };
}

function docToEvent(d: DocumentSnapshot) {
  if (!d.exists()) return null;
  const data = d.data()!;
  return {
    id: d.id,
    eventName: data.eventName ?? '',
    personFamily: data.personFamily ?? '',
    type: data.type ?? '',
    date: data.date ?? '',
    location: data.location ?? '',
    time: data.time,
    imageUrl: data.imageUrl,
    description: data.description,
  };
}

// ─── Shiurim ─────────────────────────────────────────────────────────────────

export async function fetchShiurim() {
  const snap = await getDocs(
    query(collection(db, 'shiurim'), orderBy('date', 'desc'))
  );
  return snap.docs.map(docToShiur).filter(Boolean);
}

export async function fetchMostRecentShiur() {
  const snap = await getDocs(
    query(collection(db, 'shiurim'), orderBy('date', 'desc'), limit(1))
  );
  return snap.docs[0] ? docToShiur(snap.docs[0]) : null;
}

export async function incrementPlayCount(shiurId: string) {
  await updateDoc(doc(db, 'shiurim', shiurId), { playCount: increment(1) });
}

// ─── Events ──────────────────────────────────────────────────────────────────

export async function fetchEvents() {
  const snap = await getDocs(
    query(collection(db, 'events'), orderBy('date', 'asc'))
  );
  return snap.docs.map(docToEvent).filter(Boolean);
}

export async function fetchUpcomingEvents(eventLimit = 3) {
  const today = new Date().toISOString().split('T')[0];
  const snap = await getDocs(
    query(
      collection(db, 'events'),
      where('date', '>=', today),
      orderBy('date', 'asc'),
      limit(eventLimit)
    )
  );
  return snap.docs.map(docToEvent).filter(Boolean);
}

// ─── Announcements ───────────────────────────────────────────────────────────

export async function fetchAnnouncements() {
  const snap = await getDocs(
    query(
      collection(db, 'announcements'),
      where('enabled', '==', true),
      orderBy('date', 'desc')
    )
  );
  return snap.docs.map((d) => {
    const data = d.data();
    return {
      id: d.id,
      title: data.title ?? '',
      content: data.content ?? '',
      type: data.type ?? 'announcement',
      date: data.date ?? '',
      enabled: data.enabled ?? false,
    };
  });
}

// ─── Carousel Images ─────────────────────────────────────────────────────────

export async function fetchCarouselImages() {
  const snap = await getDocs(collection(db, 'carouselImages'));
  return snap.docs
    .map((d) => {
      const data = d.data();
      return { id: d.id, url: data.url ?? '', caption: data.caption, order: data.order ?? 0 };
    })
    .sort((a, b) => a.order - b.order);
}

// ─── Contacts ────────────────────────────────────────────────────────────────

export async function fetchRebbeim() {
  const snap = await getDocs(collection(db, 'rebbeim'));
  return snap.docs.map((d) => {
    const data = d.data();
    return {
      id: d.id,
      name: data.name ?? '',
      title: data.title ?? '',
      email: data.email,
      phone: data.phone,
      photoUrl: data.photoUrl,
    };
  });
}

export async function fetchApprovedAlumni() {
  const snap = await getDocs(collection(db, 'alumniContactSubmissions'));
  return snap.docs
    .filter((d) => d.data().status === 'approved')
    .map((d) => {
      const data = d.data();
      return {
        id: d.id,
        name: data.name ?? '',
        email: data.email,
        phone: data.phone,
        location: data.location ?? '',
        submittedAt: data.submittedAt,
      };
    })
    .sort((a, b) => a.name.localeCompare(b.name));
}

// ─── Auth helpers ─────────────────────────────────────────────────────────────

export async function checkUserApproval(email: string): Promise<{ approved: boolean; admin: boolean }> {
  const normalizedEmail = email.toLowerCase();
  let approved = false;
  let admin = false;

  try {
    // 1. Check alumniDatabase
    const alumniDoc = await getDoc(doc(db, 'alumniDatabase', normalizedEmail));
    if (alumniDoc.exists()) approved = true;

    // 2. Fallback: approvedEmails by doc ID
    if (!approved) {
      const approvedDoc = await getDoc(doc(db, 'approvedEmails', normalizedEmail));
      if (approvedDoc.exists()) approved = true;
    }

    // 3. Fallback: approvedEmails by field
    if (!approved) {
      const q = query(collection(db, 'approvedEmails'), where('email', '==', normalizedEmail));
      const snap = await getDocs(q);
      if (!snap.empty) approved = true;
    }

    // 4. Admin check
    const adminDoc = await getDoc(doc(db, 'admins', normalizedEmail));
    if (adminDoc.exists()) admin = true;
  } catch (e) {
    console.warn('Approval check error:', e);
  }

  return { approved, admin };
}

export async function submitAccessRequest(email: string, name: string) {
  await addDoc(collection(db, 'accessRequests'), {
    email,
    name,
    requestedAt: serverTimestamp(),
    status: 'pending',
  });
}

export { onAuthStateChanged, User };
export type { DocumentSnapshot };
