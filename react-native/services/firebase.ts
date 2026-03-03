import {
  collection,
  getDocs,
  addDoc,
  updateDoc,
  doc,
  query,
  orderBy,
  where,
  limit,
  getDoc,
} from 'firebase/firestore';
import { db } from './firebaseConfig';

// ─── Types ───────────────────────────────────────────────────────

export interface Shiur {
  id: string;
  title: string;
  rebbe: string;
  date: string;
  tags: string[];
  audioUrl?: string;
  pdfUrl?: string;
  description?: string;
  playCount?: number;
  downloadCount?: number;
  series?: string;
}

export interface Event {
  id: string;
  eventName: string;
  personFamily: string;
  type: string;
  date: string;
  location: string;
  time?: string;
  imageUrl?: string;
  description?: string;
}

export interface Announcement {
  id: string;
  title: string;
  content: string;
  type: string;
  date: string;
  enabled: boolean;
}

export interface CarouselImage {
  id: string;
  url: string;
  caption?: string;
  order: number;
}

export interface AlumniPhoto {
  id: string;
  url: string;
  caption?: string;
  name?: string;
  year?: string;
  order: number;
}

export interface Rebbe {
  id: string;
  name: string;
  title: string;
  email?: string;
  phone?: string;
  photoUrl?: string;
}

export interface AlumniContact {
  id: string;
  name: string;
  email?: string;
  phone?: string;
  location: string;
  submittedAt?: string;
}

export interface ShiurCollection {
  id: string;
  name: string;
  description: string;
  isActive: boolean;
  shiurIds?: string[];
}

// ─── Fetch Functions ─────────────────────────────────────────────

export async function fetchShiurim(): Promise<Shiur[]> {
  const q = query(collection(db, 'shiurim'), orderBy('date', 'desc'));
  const snapshot = await getDocs(q);
  return snapshot.docs.map((d) => ({ id: d.id, ...d.data() } as Shiur));
}

export async function fetchMostRecentShiur(): Promise<Shiur | null> {
  const q = query(collection(db, 'shiurim'), orderBy('date', 'desc'), limit(1));
  const snapshot = await getDocs(q);
  if (snapshot.empty) return null;
  const d = snapshot.docs[0];
  return { id: d.id, ...d.data() } as Shiur;
}

export async function fetchEvents(): Promise<Event[]> {
  const q = query(collection(db, 'events'), orderBy('date', 'asc'));
  const snapshot = await getDocs(q);
  return snapshot.docs.map((d) => ({ id: d.id, ...d.data() } as Event));
}

export async function fetchUpcomingEvents(eventLimit = 3): Promise<Event[]> {
  const today = new Date().toISOString().split('T')[0];
  const q = query(
    collection(db, 'events'),
    where('date', '>=', today),
    orderBy('date', 'asc'),
    limit(eventLimit)
  );
  const snapshot = await getDocs(q);
  return snapshot.docs.map((d) => ({ id: d.id, ...d.data() } as Event));
}

export async function fetchAnnouncements(): Promise<Announcement[]> {
  const q = query(
    collection(db, 'announcements'),
    where('enabled', '==', true),
    orderBy('date', 'desc')
  );
  const snapshot = await getDocs(q);
  return snapshot.docs.map((d) => ({ id: d.id, ...d.data() } as Announcement));
}

export async function fetchCarouselImages(): Promise<CarouselImage[]> {
  const snapshot = await getDocs(collection(db, 'carouselImages'));
  return snapshot.docs
    .map((d) => ({ id: d.id, ...d.data() } as CarouselImage))
    .sort((a, b) => a.order - b.order);
}

export async function fetchAlumniPhotos(): Promise<AlumniPhoto[]> {
  const snapshot = await getDocs(collection(db, 'alumniPhotos'));
  return snapshot.docs
    .map((d) => ({ id: d.id, ...d.data() } as AlumniPhoto))
    .sort((a, b) => a.order - b.order);
}

export async function fetchRebbeim(): Promise<Rebbe[]> {
  const snapshot = await getDocs(collection(db, 'rebbeim'));
  return snapshot.docs.map((d) => ({ id: d.id, ...d.data() } as Rebbe));
}

export async function fetchApprovedAlumni(): Promise<AlumniContact[]> {
  const snapshot = await getDocs(collection(db, 'alumniContactSubmissions'));
  return snapshot.docs
    .filter((d) => d.data().status === 'approved')
    .map((d) => ({ id: d.id, ...d.data() } as AlumniContact))
    .sort((a, b) => a.name.localeCompare(b.name));
}

export async function fetchActiveCollection(): Promise<ShiurCollection | null> {
  const snapshot = await getDocs(collection(db, 'shiurCollections'));
  for (const d of snapshot.docs) {
    const data = d.data();
    if (data.isActive) return { id: d.id, ...data } as ShiurCollection;
  }
  return null;
}

export async function fetchFeaturedShiur(): Promise<Shiur | null> {
  const settingsDoc = await getDoc(doc(db, 'settings', 'featuredShiur'));
  if (!settingsDoc.exists()) return null;
  const data = settingsDoc.data();
  if (!data?.enabled || !data?.shiurId) return null;
  const shiurDoc = await getDoc(doc(db, 'shiurim', data.shiurId));
  if (!shiurDoc.exists()) return null;
  return { id: shiurDoc.id, ...shiurDoc.data() } as Shiur;
}

// ─── Submissions ─────────────────────────────────────────────────

export async function submitContactInfo(
  name: string,
  email: string | null,
  phone: string | null,
  location: string,
  submittedBy: string
) {
  await addDoc(collection(db, 'alumniContactSubmissions'), {
    name,
    email,
    phone,
    location,
    submittedBy,
    submittedAt: new Date().toISOString(),
    status: 'pending',
  });
}

export async function updateContactInfo(
  documentId: string,
  name: string,
  phone: string | null,
  location: string
) {
  await updateDoc(doc(db, 'alumniContactSubmissions', documentId), {
    name,
    phone,
    location,
  });
}

export async function incrementPlayCount(shiurId: string) {
  const ref = doc(db, 'shiurim', shiurId);
  const snap = await getDoc(ref);
  if (snap.exists()) {
    const current = snap.data().playCount || 0;
    await updateDoc(ref, { playCount: current + 1 });
  }
}
