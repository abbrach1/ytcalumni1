import React, { useState, useEffect, useRef } from 'react';
import {
  View,
  Text,
  ScrollView,
  TouchableOpacity,
  StyleSheet,
  Dimensions,
  Image,
  ActivityIndicator,
  FlatList,
  Platform,
  RefreshControl,
} from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { useRouter } from 'expo-router';
import { Colors } from '../../constants/Colors';
import { useAuth } from '../../hooks/useAuth';
import { useAudioPlayer } from '../../hooks/useAudioPlayer';
import {
  fetchCarouselImages,
  fetchAnnouncements,
  fetchMostRecentShiur,
  fetchFeaturedShiur,
  fetchAlumniPhotos,
  fetchActiveCollection,
  CarouselImage,
  Announcement,
  Shiur,
  AlumniPhoto,
  ShiurCollection,
} from '../../services/firebase';

const { width: SCREEN_WIDTH } = Dimensions.get('window');

export default function HomeScreen() {
  const { signOut, isAdmin } = useAuth();
  const audioPlayer = useAudioPlayer();
  const router = useRouter();

  const [carouselImages, setCarouselImages] = useState<CarouselImage[]>([]);
  const [announcements, setAnnouncements] = useState<Announcement[]>([]);
  const [mostRecentShiur, setMostRecentShiur] = useState<Shiur | null>(null);
  const [featuredShiur, setFeaturedShiur] = useState<Shiur | null>(null);
  const [alumniPhotos, setAlumniPhotos] = useState<AlumniPhoto[]>([]);
  const [activeCollection, setActiveCollection] = useState<ShiurCollection | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [showAllAnnouncements, setShowAllAnnouncements] = useState(false);
  const [carouselIndex, setCarouselIndex] = useState(0);
  const [refreshing, setRefreshing] = useState(false);

  const carouselTimer = useRef<ReturnType<typeof setInterval> | null>(null);

  const loadData = async () => {
    try {
      const [images, anns, recent, featured, photos, collection] = await Promise.all([
        fetchCarouselImages(),
        fetchAnnouncements(),
        fetchMostRecentShiur(),
        fetchFeaturedShiur(),
        fetchAlumniPhotos(),
        fetchActiveCollection(),
      ]);
      setCarouselImages(images);
      setAnnouncements(anns);
      setMostRecentShiur(recent);
      setFeaturedShiur(featured);
      setAlumniPhotos(photos);
      setActiveCollection(collection);
    } catch (error) {
      console.error('Error loading home data:', error);
    }
    setIsLoading(false);
  };

  useEffect(() => {
    loadData();
  }, []);

  // Auto-rotate carousel
  useEffect(() => {
    if (carouselImages.length <= 1) return;
    carouselTimer.current = setInterval(() => {
      setCarouselIndex((prev) => (prev + 1) % carouselImages.length);
    }, 4000);
    return () => {
      if (carouselTimer.current) clearInterval(carouselTimer.current);
    };
  }, [carouselImages.length]);

  const onRefresh = async () => {
    setRefreshing(true);
    await loadData();
    setRefreshing(false);
  };

  const displayedAnnouncements = showAllAnnouncements
    ? announcements
    : announcements.slice(0, 3);

  const handlePlayShiur = async (shiur: Shiur) => {
    if (audioPlayer.currentShiurId === shiur.id) {
      audioPlayer.togglePlayPause();
    } else {
      await audioPlayer.play(shiur);
    }
  };

  return (
    <ScrollView
      style={styles.container}
      showsVerticalScrollIndicator={false}
      refreshControl={<RefreshControl refreshing={refreshing} onRefresh={onRefresh} tintColor={Colors.gold} />}
    >
      {/* Header with Carousel */}
      <View style={styles.header}>
        {carouselImages.length > 0 && carouselImages[carouselIndex]?.url ? (
          <Image
            source={{ uri: carouselImages[carouselIndex].url }}
            style={styles.carouselImage}
            resizeMode="cover"
          />
        ) : (
          <View style={[styles.carouselImage, { backgroundColor: Colors.navy }]} />
        )}

        {/* Overlay gradient */}
        <View style={styles.headerOverlay} />

        {/* Profile menu */}
        <View style={styles.profileMenu}>
          <TouchableOpacity
            onPress={signOut}
            style={styles.profileButton}
          >
            <Ionicons name="person-circle" size={32} color={Colors.white} />
          </TouchableOpacity>
        </View>

        {/* Title */}
        <View style={styles.headerTitle}>
          <View style={styles.goldLine} />
          <Text style={styles.headerTitleText}>Yeshiva Toras Chaim</Text>
          <Text style={styles.headerSubtitle}>ALUMNI NETWORK</Text>
          <View style={styles.goldLine} />
        </View>
      </View>

      {/* Main content */}
      <View style={styles.content}>
        {/* Announcements */}
        {announcements.length > 0 && (
          <View style={styles.section}>
            <SectionHeader title="Announcements" icon="megaphone" />
            {displayedAnnouncements.map((ann) => (
              <AnnouncementCard key={ann.id} announcement={ann} />
            ))}
            {announcements.length > 3 && (
              <TouchableOpacity onPress={() => setShowAllAnnouncements(!showAllAnnouncements)}>
                <Text style={styles.showMoreText}>
                  {showAllAnnouncements ? 'Show Less' : `Show All (${announcements.length})`}
                </Text>
              </TouchableOpacity>
            )}
          </View>
        )}

        {/* Featured Shiur */}
        {featuredShiur && (
          <View style={styles.section}>
            <SectionHeader title="Featured Shiur" icon="headset" />
            <ShiurHomeCard
              shiur={featuredShiur}
              isPlaying={audioPlayer.currentShiurId === featuredShiur.id && audioPlayer.isPlaying}
              onPlay={() => handlePlayShiur(featuredShiur)}
            />
          </View>
        )}

        {/* Most Recent Shiur */}
        {mostRecentShiur && mostRecentShiur.id !== featuredShiur?.id && (
          <View style={styles.section}>
            <SectionHeader title="Most Recent Shiur" icon="headset" />
            <ShiurHomeCard
              shiur={mostRecentShiur}
              isPlaying={audioPlayer.currentShiurId === mostRecentShiur.id && audioPlayer.isPlaying}
              onPlay={() => handlePlayShiur(mostRecentShiur)}
            />
          </View>
        )}

        {/* Alumni Spotlight */}
        {alumniPhotos.length > 0 && (
          <View style={styles.section}>
            <SectionHeader title="Alumni Spotlight" icon="people" />
            <View style={styles.photoGrid}>
              {alumniPhotos.slice(0, 4).map((photo) => (
                <View key={photo.id} style={styles.photoCard}>
                  <Image
                    source={{ uri: photo.url }}
                    style={styles.photoImage}
                    resizeMode="cover"
                  />
                  {(photo.name || photo.year) && (
                    <View style={styles.photoInfo}>
                      {photo.name ? (
                        <Text style={styles.photoName} numberOfLines={1}>{photo.name}</Text>
                      ) : null}
                      {photo.year ? (
                        <Text style={styles.photoYear}>Class of {photo.year}</Text>
                      ) : null}
                    </View>
                  )}
                </View>
              ))}
            </View>
          </View>
        )}
      </View>

      {/* Bottom padding for mini player */}
      <View style={{ height: audioPlayer.currentShiurId ? 100 : 20 }} />
    </ScrollView>
  );
}

// --- Sub-components ---

function SectionHeader({ title, icon }: { title: string; icon: string }) {
  return (
    <View style={styles.sectionHeader}>
      <Ionicons name={icon as any} size={20} color={Colors.gold} />
      <Text style={styles.sectionTitle}>{title}</Text>
    </View>
  );
}

function AnnouncementCard({ announcement }: { announcement: Announcement }) {
  const isMazelTov = announcement.type === 'mazel_tov';
  return (
    <View style={styles.announcementCard}>
      <View style={styles.announcementIcon}>
        <Ionicons
          name={isMazelTov ? 'sparkles' : 'megaphone'}
          size={18}
          color={Colors.gold}
        />
      </View>
      <View style={styles.announcementContent}>
        <Text style={styles.announcementTitle}>{announcement.title}</Text>
        <Text style={styles.announcementBody} numberOfLines={2}>
          {announcement.content}
        </Text>
      </View>
    </View>
  );
}

function ShiurHomeCard({
  shiur,
  isPlaying,
  onPlay,
}: {
  shiur: Shiur;
  isPlaying: boolean;
  onPlay: () => void;
}) {
  return (
    <View style={styles.shiurCard}>
      <Text style={styles.shiurTitle}>{shiur.title}</Text>
      <Text style={styles.shiurRebbe}>{shiur.rebbe}</Text>

      {shiur.tags && shiur.tags.length > 0 && (
        <ScrollView horizontal showsHorizontalScrollIndicator={false} style={{ marginTop: 8 }}>
          <View style={styles.tagRow}>
            {shiur.tags.map((tag) => (
              <View key={tag} style={styles.tag}>
                <Text style={styles.tagText}>{tag}</Text>
              </View>
            ))}
          </View>
        </ScrollView>
      )}

      {shiur.audioUrl && (
        <TouchableOpacity style={styles.playButtonFull} onPress={onPlay}>
          <Ionicons name={isPlaying ? 'pause' : 'play'} size={18} color={Colors.cream} />
          <Text style={styles.playButtonText}>{isPlaying ? 'Pause' : 'Play'}</Text>
        </TouchableOpacity>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: Colors.cream,
  },
  header: {
    height: 350,
    position: 'relative',
  },
  carouselImage: {
    ...StyleSheet.absoluteFillObject,
    width: '100%',
    height: '100%',
  },
  headerOverlay: {
    ...StyleSheet.absoluteFillObject,
    backgroundColor: 'rgba(0,0,0,0.45)',
  },
  profileMenu: {
    position: 'absolute',
    top: 50,
    right: 16,
    zIndex: 10,
  },
  profileButton: {
    opacity: 0.9,
  },
  headerTitle: {
    position: 'absolute',
    bottom: 40,
    left: 0,
    right: 0,
    alignItems: 'center',
  },
  goldLine: {
    width: 50,
    height: 3,
    backgroundColor: Colors.gold,
    marginVertical: 8,
  },
  headerTitleText: {
    fontSize: 28,
    fontWeight: 'bold',
    color: Colors.white,
    fontFamily: Platform.OS === 'ios' ? 'Georgia' : 'serif',
    textShadowColor: 'rgba(0,0,0,0.3)',
    textShadowOffset: { width: 0, height: 1 },
    textShadowRadius: 2,
  },
  headerSubtitle: {
    fontSize: 13,
    fontWeight: '600',
    color: Colors.gold,
    letterSpacing: 4,
    marginTop: 4,
  },
  content: {
    paddingHorizontal: 16,
    paddingVertical: 24,
    gap: 28,
  },
  section: {
    gap: 16,
  },
  sectionHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
  },
  sectionTitle: {
    fontSize: 20,
    fontWeight: 'bold',
    color: Colors.navy,
    fontFamily: Platform.OS === 'ios' ? 'Georgia' : 'serif',
  },
  // Announcements
  announcementCard: {
    flexDirection: 'row',
    alignItems: 'flex-start',
    padding: 16,
    backgroundColor: Colors.white,
    borderRadius: 16,
    gap: 12,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.08,
    shadowRadius: 10,
    elevation: 3,
  },
  announcementIcon: {
    width: 32,
    height: 32,
    borderRadius: 8,
    backgroundColor: Colors.goldOpacity(0.15),
    alignItems: 'center',
    justifyContent: 'center',
  },
  announcementContent: {
    flex: 1,
  },
  announcementTitle: {
    fontSize: 14,
    fontWeight: '600',
    color: Colors.navy,
  },
  announcementBody: {
    fontSize: 12,
    color: Colors.navyOpacity(0.7),
    marginTop: 2,
  },
  showMoreText: {
    fontSize: 14,
    fontWeight: '500',
    color: Colors.gold,
  },
  // Shiur card
  shiurCard: {
    padding: 20,
    backgroundColor: Colors.white,
    borderRadius: 16,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.08,
    shadowRadius: 10,
    elevation: 3,
  },
  shiurTitle: {
    fontSize: 17,
    fontWeight: '600',
    color: Colors.navy,
  },
  shiurRebbe: {
    fontSize: 15,
    color: Colors.navyOpacity(0.7),
    marginTop: 4,
  },
  tagRow: {
    flexDirection: 'row',
    gap: 6,
  },
  tag: {
    paddingHorizontal: 8,
    paddingVertical: 4,
    backgroundColor: Colors.goldOpacity(0.15),
    borderRadius: 4,
  },
  tagText: {
    fontSize: 11,
    fontWeight: '500',
    color: Colors.gold,
  },
  playButtonFull: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 8,
    backgroundColor: Colors.navy,
    borderRadius: 10,
    paddingVertical: 14,
    marginTop: 16,
  },
  playButtonText: {
    fontSize: 15,
    fontWeight: '600',
    color: Colors.cream,
  },
  // Alumni photos
  photoGrid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 12,
  },
  photoCard: {
    width: (SCREEN_WIDTH - 44) / 2,
    backgroundColor: Colors.white,
    borderRadius: 10,
    overflow: 'hidden',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.08,
    shadowRadius: 4,
    elevation: 2,
  },
  photoImage: {
    width: '100%',
    height: 90,
  },
  photoInfo: {
    padding: 8,
  },
  photoName: {
    fontSize: 12,
    fontWeight: '600',
    color: Colors.navy,
  },
  photoYear: {
    fontSize: 10,
    color: Colors.gold,
    marginTop: 2,
  },
});
