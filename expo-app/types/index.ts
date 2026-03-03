// Shiur model
export interface Shiur {
  id: string;
  title: string;
  rebbe: string;
  date: string; // "YYYY-MM-DD"
  tags: string[];
  audioUrl?: string;
  pdfUrl?: string;
  description?: string;
  playCount?: number;
  downloadCount?: number;
  series?: string;
}

// Event model
export interface YTCEvent {
  id: string;
  eventName: string;
  personFamily: string;
  type: string;
  date: string; // "YYYY-MM-DD"
  location: string;
  time?: string;
  imageUrl?: string;
  description?: string;
}

// Announcement model
export interface Announcement {
  id: string;
  title: string;
  content: string;
  type: 'mazel_tov' | 'announcement';
  date: string;
  enabled: boolean;
}

// Carousel image model
export interface CarouselImage {
  id: string;
  url: string;
  caption?: string;
  order: number;
}

// Alumni contact model
export interface AlumniContact {
  id: string;
  name: string;
  email?: string;
  phone?: string;
  location: string;
  submittedAt?: string;
}

// Rebbe model
export interface Rebbe {
  id: string;
  name: string;
  title: string;
  email?: string;
  phone?: string;
  photoUrl?: string;
}

// User profile
export interface UserProfile {
  uid: string;
  email: string;
  displayName?: string;
  isApproved: boolean;
  isAdmin: boolean;
}
